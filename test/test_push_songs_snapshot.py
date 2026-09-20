#!/usr/bin/env python3
"""Tests for `scripts/push_songs_snapshot.py`.

Run:
    python3 test/test_push_songs_snapshot.py

stdlib `unittest`, matching `test_pull_songs_snapshot.py`: this repo has
no pytest. Every test here builds its own bare remote + clones under a
`tempfile.TemporaryDirectory()` and never touches the real repo or the
network — safe on a bare CI runner.

This exists because of a real incident: 2026-09-20, `sync-songs.yml`'s
`git push` raced this repo's own autonomous loop and lost
(`! [rejected] main -> main (fetch first)`), silently dropping a day's
song-catalogue refresh. The fix re-applies the snapshot onto the new
tip on a rejected push rather than rebasing (the workflow's checkout is
shallow, so there is no merge base to rebase onto). The trap the fix
specifically avoids is `git reset --soft`, which would leave the index
holding the whole pre-reset tree and silently revert any OTHER file the
winning commit touched — every test below that involves a competing
commit asserts that file survives untouched.
"""

import importlib.util
import os
import subprocess
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'scripts', 'push_songs_snapshot.py')

_spec = importlib.util.spec_from_file_location('push_songs_snapshot', SCRIPT)
pss = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pss)


def _run(args, cwd):
    result = subprocess.run(
        ['git', *args], cwd=cwd, capture_output=True, text=True)
    assert result.returncode == 0, (
        f'git {" ".join(args)} failed in {cwd}:\n{result.stdout}\n{result.stderr}')
    return result


def _init_repo(path):
    os.makedirs(path, exist_ok=True)
    _run(['init', '--initial-branch=main', '-q', '.'], path)
    _run(['config', 'user.name', 'Test'], path)
    _run(['config', 'user.email', 'test@example.org'], path)
    return path


def _write(path, relative, content):
    full = os.path.join(path, relative)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(content)


def _no_sleep(_seconds):
    pass


class PushSongsSnapshotTestCase(unittest.TestCase):
    """Sets up a bare remote plus a `local` clone that already carries a
    baseline `assets/songs.json` and `other.txt`, and a `racer` clone
    used to land competing commits on the remote mid-test."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = self._tmp.name

        self.bare = os.path.join(root, 'remote.git')
        os.makedirs(self.bare)
        _run(['init', '--bare', '--initial-branch=main', '-q', '.'], self.bare)

        seed = _init_repo(os.path.join(root, 'seed'))
        _write(seed, 'assets/songs.json', '{"songs": ["baseline"]}\n')
        _write(seed, 'other.txt', 'other content, untouched by songs sync\n')
        _run(['add', '.'], seed)
        _run(['commit', '-q', '-m', 'baseline'], seed)
        _run(['remote', 'add', 'origin', self.bare], seed)
        _run(['push', '-q', 'origin', 'main'], seed)

        self.local = os.path.join(root, 'local')
        _run(['clone', '-q', self.bare, self.local], root)
        _run(['config', 'user.name', 'Test'], self.local)
        _run(['config', 'user.email', 'test@example.org'], self.local)

        self.racer = os.path.join(root, 'racer')
        _run(['clone', '-q', self.bare, self.racer], root)
        _run(['config', 'user.name', 'Racer'], self.racer)
        _run(['config', 'user.email', 'racer@example.org'], self.racer)

    def _racer_push(self, relative_path, content, message):
        """Lands one commit from the racer clone straight onto the remote,
        simulating the OTHER workflow that shares this branch."""
        _write(self.racer, relative_path, content)
        _run(['add', relative_path], self.racer)
        _run(['commit', '-q', '-m', message], self.racer)
        _run(['push', '-q', 'origin', 'main'], self.racer)

    def _fetch_remote_file(self, relative_path):
        # Fetch into a scratch clone so we read the remote's true current
        # state, independent of whatever the local/racer clones have
        # cached locally.
        scratch = tempfile.mkdtemp(dir=self._tmp.name)
        _run(['clone', '-q', self.bare, scratch], self._tmp.name)
        with open(os.path.join(scratch, relative_path), encoding='utf-8') as f:
            return f.read()


class NoRaceSucceedsFirstTry(PushSongsSnapshotTestCase):
    def test_pushes_on_first_attempt_when_nobody_races(self):
        _write(self.local, 'assets/songs.json', '{"songs": ["fresh"]}\n')

        attempt = pss.commit_and_push_with_retry(
            self.local, 'assets/songs.json', 'chore(songs): refresh',
            sleep_fn=_no_sleep)

        self.assertEqual(attempt, 1)
        self.assertEqual(
            self._fetch_remote_file('assets/songs.json'),
            '{"songs": ["fresh"]}\n')


class CompetingCommitOnAnotherFileIsPreserved(PushSongsSnapshotTestCase):
    """The `--soft` trap: a naive re-commit after reset could wipe out
    whatever the winning commit touched. This is the assertion that
    would have caught it."""

    def test_race_on_different_file_reapplies_snapshot_and_keeps_racer_file(self):
        _write(self.local, 'assets/songs.json', '{"songs": ["fresh"]}\n')

        def before_push(attempt):
            if attempt == 1:
                self._racer_push(
                    'other.txt', 'racer edited this concurrently\n',
                    'racer: unrelated concurrent change')

        attempt = pss.commit_and_push_with_retry(
            self.local, 'assets/songs.json', 'chore(songs): refresh',
            sleep_fn=_no_sleep, before_push_hook=before_push)

        self.assertEqual(attempt, 2, 'expected exactly one retry')
        self.assertEqual(
            self._fetch_remote_file('assets/songs.json'),
            '{"songs": ["fresh"]}\n')
        self.assertEqual(
            self._fetch_remote_file('other.txt'),
            'racer edited this concurrently\n',
            "the racer's unrelated file must survive the reset+reapply "
            'untouched — this is the git reset --soft trap')


class CompetingCommitOnSameFileOursWins(PushSongsSnapshotTestCase):
    def test_race_on_songs_json_itself_our_fresh_pull_wins(self):
        _write(self.local, 'assets/songs.json', '{"songs": ["fresh"]}\n')

        def before_push(attempt):
            if attempt == 1:
                self._racer_push(
                    'assets/songs.json', '{"songs": ["racer-stale"]}\n',
                    'racer: also touched songs.json')

        attempt = pss.commit_and_push_with_retry(
            self.local, 'assets/songs.json', 'chore(songs): refresh',
            sleep_fn=_no_sleep, before_push_hook=before_push)

        self.assertEqual(attempt, 2)
        self.assertEqual(
            self._fetch_remote_file('assets/songs.json'),
            '{"songs": ["fresh"]}\n',
            'the freshly-pulled snapshot must win over a stale racer '
            'write to the same file')


class BoundIsExhaustedNoisily(PushSongsSnapshotTestCase):
    def test_persistent_race_exhausts_attempts_and_raises(self):
        _write(self.local, 'assets/songs.json', '{"songs": ["fresh"]}\n')
        racer_commits = {'n': 0}

        def always_race(attempt):
            racer_commits['n'] += 1
            self._racer_push(
                'other.txt', f'racer change #{racer_commits["n"]}\n',
                f'racer: concurrent change {racer_commits["n"]}')

        with self.assertRaises(pss.PushFailed):
            pss.commit_and_push_with_retry(
                self.local, 'assets/songs.json', 'chore(songs): refresh',
                max_attempts=3, sleep_fn=_no_sleep,
                before_push_hook=always_race)

        # Never a silent success: our commit did not land.
        self.assertEqual(
            self._fetch_remote_file('assets/songs.json'),
            '{"songs": ["baseline"]}\n')
        self.assertEqual(racer_commits['n'], 3,
                          'every attempt should have raced, including the '
                          'last — the bound must be enforced by attempt '
                          'count, not by the hook running out')


class NonRaceRejectionIsNotRetried(PushSongsSnapshotTestCase):
    """A protected-branch or auth rejection must fail immediately, not be
    treated as the fetch-first race this script exists to paper over."""

    def test_pre_receive_rejection_raises_without_retry(self):
        hooks_dir = os.path.join(self.bare, 'hooks')
        pre_receive = os.path.join(hooks_dir, 'pre-receive')
        with open(pre_receive, 'w', encoding='utf-8') as f:
            f.write('#!/bin/sh\necho "policy: direct pushes disabled" >&2\nexit 1\n')
        os.chmod(pre_receive, 0o755)

        _write(self.local, 'assets/songs.json', '{"songs": ["fresh"]}\n')

        calls = {'n': 0}

        def count_calls(_attempt):
            calls['n'] += 1

        with self.assertRaises(pss.PushFailed) as ctx:
            pss.commit_and_push_with_retry(
                self.local, 'assets/songs.json', 'chore(songs): refresh',
                max_attempts=3, sleep_fn=_no_sleep,
                before_push_hook=count_calls)

        self.assertIn('not retrying', str(ctx.exception))
        self.assertEqual(calls['n'], 1,
                          'a non-race rejection must not be retried')


if __name__ == '__main__':
    unittest.main()
