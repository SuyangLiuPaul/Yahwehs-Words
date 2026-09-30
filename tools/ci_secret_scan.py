#!/usr/bin/env python3
"""Scan immutable CI event commits; never query the PR's mutable commit list.

On 2026-10-01 three documentation-only runs reached Gitleaks minutes after
checkout, while another push had advanced the PR. gitleaks-action's live
pulls/{number}/commits request selected an object not in that checkout.
The saved event plus GITHUB_SHA are the scope of THIS run. Missing objects,
a different checkout and an unsupported event are errors, never clean scans.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys


class ScanError(RuntimeError):
    pass


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode:
        # Git object errors contain no file content. Do not expose scanner
        # findings through this exception path; Gitleaks redacts its output.
        raise ScanError(f"git {args[0]} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def commit_sha(value, label):
    if not isinstance(value, str) or not re.fullmatch(
        r"[0-9a-f]{40}|[0-9a-f]{64}", value
    ):
        raise ScanError(f"{label} must be a complete immutable commit SHA")
    if not value.strip("0"):
        raise ScanError(f"{label} is not a commit")
    return value


def require_commit(sha):
    # A force push can leave `before` unreachable from all current refs.
    # Fetch THAT immutable object if needed, never a moving branch name.
    exists = subprocess.run(["git", "cat-file", "-e", f"{sha}^{{commit}}"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if exists.returncode:
        git("fetch", "--no-tags", "origin", sha)
    git("cat-file", "-e", f"{sha}^{{commit}}")


def scan_range(event_name, event, checked_out_sha):
    sha = commit_sha(checked_out_sha, "GITHUB_SHA")
    if git("rev-parse", "HEAD") != sha:
        raise ScanError("checkout HEAD differs from GITHUB_SHA; refusing to scan another revision")
    if git("rev-parse", "--is-shallow-repository") != "false":
        raise ScanError("checkout is shallow; complete history is required")
    require_commit(sha)
    if event_name == "pull_request":
        pr = event["pull_request"]
        base = commit_sha(pr["base"]["sha"], "PR event base")
        head = commit_sha(pr["head"]["sha"], "PR event head")
        require_commit(base)
        require_commit(head)
        git("merge-base", "--is-ancestor", head, sha)
        git("merge-base", "--is-ancestor", base, sha)
        # Include every branch commit introduced by the PR, plus the event's
        # tested merge resolution. --first-parent/--no-merges would miss
        # secrets on merged side branches or introduced by a merge itself.
        revision = f"{base}..{sha}"
    elif event_name == "push":
        after = commit_sha(event["after"], "push event after")
        if after != sha:
            raise ScanError("push event after differs from GITHUB_SHA")
        before = event["before"]
        if isinstance(before, str) and re.fullmatch(r"0{40}|0{64}", before):
            revision = sha  # New branch: scan all history reachable from it.
        else:
            base = commit_sha(before, "push event before")
            require_commit(base)
            revision = f"{base}..{sha}"
    else:
        raise ScanError(f"unsupported scan event: {event_name}")
    if int(git("rev-list", "--count", revision)) == 0:
        raise ScanError("event has no commits to scan; refusing an empty success")
    return revision


def main():
    try:
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        revision = scan_range(os.environ["GITHUB_EVENT_NAME"], event, os.environ["GITHUB_SHA"])
        if not Path(".gitleaks.toml").is_file():
            raise ScanError("required project .gitleaks.toml is missing")
        scanner = os.environ.get("GITLEAKS_BINARY", "gitleaks")
        print(f"Scanning immutable event range: {revision}", flush=True)
        return subprocess.run([
            scanner, "git", "--redact=100", "--no-color", "--exit-code=2",
            "--config=.gitleaks.toml", "--gitleaks-ignore-path=.",
            "--report-format=sarif", "--report-path=results.sarif",
            f"--log-opts=--full-history --diff-merges=first-parent {revision}", ".",
        ]).returncode
    except (ScanError, KeyError, ValueError, OSError) as error:
        print(f"Secret scan failed closed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
