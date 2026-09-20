#!/usr/bin/env python3
"""Commit and push `assets/songs.json` with a bounded fetch+reapply retry.

`.github/workflows/sync-songs.yml` runs daily at 02:00 UTC and pushes
straight to `main` with a plain `git commit` + `git push`. This repo's
own autonomous loop also pushes to `main`, roughly hourly, so the two
can race: on 2026-09-20 the loop's `a4912a0b` landed ~16 seconds ahead
of the cron's push, which then failed with
`! [rejected] main -> main (fetch first)` and the day's snapshot refresh
was silently dropped (`gh run view 35496958152 --log-failed`).

Why re-apply instead of `git pull --rebase`: the workflow's checkout is
a depth-1 shallow clone (no `fetch-depth:` on `actions/checkout@v4`), so
there is no merge base below the shallow boundary to rebase onto —
`fetch-depth: 0` would fix that but adds a ~337 MB history download to a
job that currently clones one commit.

By the time this script runs, `pull_songs_snapshot.py` has already
decided the final bytes for `assets/songs.json` — including its own
re-applied local enrichment (`tools/add_cdc_hymn_scores.py`) — and
written them to disk. So there is no 3-way merge to do on a rejected
push, only a straight overwrite: this reads those bytes into memory,
`git fetch`es the new tip, does `git reset --hard FETCH_HEAD` (NOT
`--soft` — soft would leave the index holding the whole old tree, and
re-committing it would silently revert whatever else the winning commit
touched), rewrites just the snapshot file back to the bytes already
decided, re-commits, and retries the push. Bounded (default 3
attempts); a rejection that isn't a fetch-first race (protected branch,
auth) is never retried.

Usage (from the workflow, after `pull_songs_snapshot.py` has already
written a new `assets/songs.json` to disk):
    python3 scripts/push_songs_snapshot.py \\
        --file assets/songs.json \\
        --message-file /tmp/commit_message.txt
"""

import argparse
import subprocess
import sys
import time


class PushFailed(RuntimeError):
    pass


def run_git(args, cwd):
    return subprocess.run(
        ['git', *args], cwd=cwd, capture_output=True, text=True)


def is_fetch_first_rejection(push_result):
    """True only for the race this script exists to retry.

    Any other non-zero push (protected branch, auth, no such remote) must
    surface immediately rather than being swallowed into a retry loop.
    """
    if push_result.returncode == 0:
        return False
    combined = (push_result.stdout or '') + (push_result.stderr or '')
    return '[rejected]' in combined and 'fetch first' in combined


def current_branch(repo_dir):
    result = run_git(['rev-parse', '--abbrev-ref', 'HEAD'], repo_dir)
    if result.returncode != 0:
        raise PushFailed(f'could not determine current branch: {result.stderr}')
    return result.stdout.strip()


def commit_and_push_with_retry(
        repo_dir, file_path, commit_message, branch=None, remote='origin',
        max_attempts=3, sleep_seconds=5, sleep_fn=time.sleep,
        before_push_hook=None):
    """Commits `file_path` (repo-relative) and pushes, retrying on a
    fetch-first race by resetting to the new tip and re-applying just
    that file. Returns the attempt number that succeeded (1-based).
    Raises PushFailed if every attempt is exhausted or the rejection is
    not a race.

    `before_push_hook`, if given, is called with the attempt number right
    before each push attempt. Production callers never pass it; tests use
    it to land a competing commit on the remote at the exact moment a race
    needs to be reproduced deterministically.
    """
    if branch is None:
        branch = current_branch(repo_dir)

    full_path = f'{repo_dir}/{file_path}'
    with open(full_path, 'rb') as f:
        content = f.read()

    for attempt in range(1, max_attempts + 1):
        add = run_git(['add', file_path], repo_dir)
        if add.returncode != 0:
            raise PushFailed(f'git add failed: {add.stderr}')

        commit = run_git(['commit', '-m', commit_message], repo_dir)
        if commit.returncode != 0:
            raise PushFailed(f'git commit failed: {commit.stderr}')

        if before_push_hook is not None:
            before_push_hook(attempt)

        push = run_git(['push', remote, f'HEAD:{branch}'], repo_dir)
        if push.returncode == 0:
            return attempt

        if not is_fetch_first_rejection(push):
            raise PushFailed(
                f'git push failed (not a fetch-first race, not retrying): '
                f'{push.stderr}')

        if attempt == max_attempts:
            raise PushFailed(
                f'git push rejected {max_attempts} time(s) in a row; '
                f'giving up. Last stderr: {push.stderr}')

        fetch = run_git(['fetch', remote, branch], repo_dir)
        if fetch.returncode != 0:
            raise PushFailed(f'git fetch failed: {fetch.stderr}')

        reset = run_git(['reset', '--hard', 'FETCH_HEAD'], repo_dir)
        if reset.returncode != 0:
            raise PushFailed(f'git reset --hard failed: {reset.stderr}')

        with open(full_path, 'wb') as f:
            f.write(content)

        sleep_fn(sleep_seconds)

    raise PushFailed('unreachable')


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--repo', default='.')
    ap.add_argument('--file', required=True,
                     help='Path to the already-written snapshot file, '
                          'relative to --repo.')
    ap.add_argument('--message', help='Commit message.')
    ap.add_argument('--message-file',
                     help='Read the commit message from this file instead '
                          'of --message.')
    ap.add_argument('--branch', default=None,
                     help='Defaults to the current branch.')
    ap.add_argument('--remote', default='origin')
    ap.add_argument('--max-attempts', type=int, default=3)
    ap.add_argument('--sleep-seconds', type=float, default=5)
    args = ap.parse_args()

    if bool(args.message) == bool(args.message_file):
        ap.error('exactly one of --message / --message-file is required')

    if args.message_file:
        with open(args.message_file, 'r', encoding='utf-8') as f:
            message = f.read()
    else:
        message = args.message

    try:
        attempt = commit_and_push_with_retry(
            args.repo, args.file, message, branch=args.branch,
            remote=args.remote, max_attempts=args.max_attempts,
            sleep_seconds=args.sleep_seconds)
    except PushFailed as e:
        print(f'ERROR: {e}', file=sys.stderr)
        return 1

    suffix = '' if attempt == 1 else f' (after {attempt - 1} retry/retries)'
    print(f'✓ pushed{suffix}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
