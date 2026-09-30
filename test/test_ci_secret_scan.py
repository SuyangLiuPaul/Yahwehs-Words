#!/usr/bin/env python3
"""Offline temp-git regressions, including real Gitleaks fail-closed scans.

Synthetic credentials are generated only inside temporary repositories.
Never print them or scanner findings. CI installs the checksum-pinned scanner
before running this file; local runs may set GITLEAKS_TEST_BINARY explicitly.
"""

import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import string
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("ci_secret_scan", ROOT / "tools/ci_secret_scan.py")
SCAN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SCAN)


class EventScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = os.environ.get("GITLEAKS_TEST_BINARY") or shutil.which("gitleaks")
        if not cls.binary or not Path(cls.binary).is_file():
            raise RuntimeError("verified Gitleaks is required; these secret-detection tests cannot be skipped")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / "repo"
        self.repo.mkdir()
        self.old_cwd = Path.cwd()
        os.chdir(self.repo)
        self.addCleanup(os.chdir, self.old_cwd)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "CI fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        shutil.copyfile(ROOT / ".gitleaks.toml", self.repo / ".gitleaks.toml")
        self.base = self.commit("readme.txt", "fixture\n", "base")

    def git(self, *args):
        return subprocess.check_output(["git", *args], stderr=subprocess.DEVNULL, text=True).strip()

    def commit(self, path, content, message):
        (self.repo / path).write_text(content)
        self.git("add", path)
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def pr_event(self, head):
        return {"pull_request": {"base": {"sha": self.base}, "head": {"sha": head}}}

    def merge(self, head):
        self.git("checkout", "-q", "main")
        self.git("merge", "--no-ff", "-q", head, "-m", "event merge")
        return self.git("rev-parse", "HEAD")

    def run_scan(self, event_name, event, sha):
        event_path = Path(self.temp.name) / "event.json"
        event_path.write_text(json.dumps(event))
        env = dict(os.environ, GITHUB_EVENT_PATH=str(event_path), GITHUB_EVENT_NAME=event_name,
                   GITHUB_SHA=sha, GITLEAKS_BINARY=str(self.binary))
        return subprocess.run(["python3", str(ROOT / "tools/ci_secret_scan.py")],
                              env=env, capture_output=True, text=True)

    def test_stale_pr_checkout_uses_saved_event_not_newer_remote_head(self):
        self.git("checkout", "-q", "-b", "feature")
        head = self.commit("feature.txt", "old event\n", "feature")
        event = self.pr_event(head)
        merged = self.merge(head)
        # The branch updates after checkout, exactly the action@v3 race.
        self.git("checkout", "-q", "feature")
        newer = self.commit("newer.txt", "new event\n", "newer")
        self.git("checkout", "-q", "--detach", merged)
        revision = SCAN.scan_range("pull_request", event, merged)
        commits = self.git("rev-list", revision).splitlines()
        self.assertIn(head, commits)
        self.assertIn(merged, commits)
        self.assertNotIn(newer, commits)
        result = self.run_scan("pull_request", event, merged)
        self.assertEqual(result.returncode, 0)

    def test_push_range_includes_all_new_commits(self):
        first = self.commit("one.txt", "one\n", "one")
        last = self.commit("two.txt", "two\n", "two")
        event = {"before": self.base, "after": last}
        revision = SCAN.scan_range("push", event, last)
        self.assertEqual(set(self.git("rev-list", revision).splitlines()), {first, last})
        self.assertEqual(self.run_scan("push", event, last).returncode, 0)

    def test_new_branch_includes_root_commit(self):
        revision = SCAN.scan_range("push", {"before": "0" * 40, "after": self.base}, self.base)
        self.assertEqual(revision, self.base)
        self.assertEqual(self.run_scan("push", {"before": "0" * 40, "after": self.base}, self.base).returncode, 0)

    def test_force_push_with_unreachable_before_is_scanned(self):
        old = self.commit("old.txt", "old branch\n", "old head")
        self.git("checkout", "-q", "--detach", self.base)
        replacement = self.commit("replacement.txt", "replacement\n", "force push")
        event = {"before": old, "after": replacement}
        revision = SCAN.scan_range("push", event, replacement)
        self.assertEqual(self.git("rev-list", revision), replacement)
        self.assertEqual(self.run_scan("push", event, replacement).returncode, 0)

    def test_missing_force_push_before_can_be_fetched_only_by_sha(self):
        old = self.commit("old.txt", "old head\n", "old head")
        remote = Path(self.temp.name) / "remote.git"
        self.git("clone", "-q", "--bare", str(self.repo), str(remote))
        self.git("--git-dir", str(remote), "config", "uploadpack.allowAnySHA1InWant", "true")
        self.git("checkout", "-q", "--detach", self.base)
        replacement = self.commit("replacement.txt", "replacement\n", "replacement")
        self.git("push", "-q", str(remote), f"{replacement}:refs/heads/main", "--force")
        clone = Path(self.temp.name) / "checkout"
        self.git("clone", "-q", "--single-branch", "--no-local", remote.as_uri(), str(clone))
        os.chdir(clone)
        missing = subprocess.run(["git", "cat-file", "-e", f"{old}^{{commit}}"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.assertNotEqual(missing.returncode, 0)
        revision = SCAN.scan_range("push", {"before": old, "after": replacement}, replacement)
        self.assertEqual(revision, f"{old}..{replacement}")
        self.assertEqual(self.git("rev-list", revision), replacement)

    def test_missing_object_fails_closed_without_report(self):
        event = {"before": "1" * 40, "after": self.base}
        result = self.run_scan("push", event, self.base)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("failed closed", result.stderr)
        self.assertFalse((self.repo / "results.sarif").exists())

    def test_mismatched_checkout_fails_closed(self):
        head = self.commit("feature.txt", "feature\n", "feature")
        result = self.run_scan("push", {"before": self.base, "after": head}, self.base)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("differs", result.stderr)

    def test_updated_pr_event_cannot_scan_stale_merge(self):
        self.git("checkout", "-q", "-b", "feature")
        head = self.commit("feature.txt", "feature\n", "feature")
        merged = self.merge(head)
        self.git("checkout", "-q", "feature")
        newer = self.commit("newer.txt", "newer\n", "newer")
        self.git("checkout", "-q", "--detach", merged)
        result = self.run_scan("pull_request", self.pr_event(newer), merged)
        self.assertNotEqual(result.returncode, 0)

    def test_shallow_checkout_fails_closed(self):
        self.commit("another.txt", "another\n", "another")
        shallow = Path(self.temp.name) / "shallow"
        self.git("clone", "-q", "--depth=1", self.repo.as_uri(), str(shallow))
        os.chdir(shallow)
        sha = self.git("rev-parse", "HEAD")
        with self.assertRaisesRegex(SCAN.ScanError, "shallow"):
            SCAN.scan_range("push", {"before": "0" * 40, "after": sha}, sha)

    def test_invalid_event_and_revision_injection_fail_closed(self):
        with self.assertRaises(SCAN.ScanError):
            SCAN.scan_range("schedule", {}, self.base)
        with self.assertRaises(SCAN.ScanError):
            SCAN.scan_range("push", {"before": "--all", "after": self.base}, self.base)

    def test_deleted_secret_is_detected_in_commit_history_and_redacted(self):
        token = "gh" + "p_" + "".join(
            secrets.SystemRandom().sample(string.ascii_letters + string.digits, 36)
        )
        secret_commit = self.commit("credential.txt", f'fixture = "{token}"\n', "synthetic credential")
        last = self.commit("credential.txt", "removed\n", "remove credential")
        result = self.run_scan("push", {"before": self.base, "after": last}, last)
        self.assertEqual(result.returncode, 2)
        report = (self.repo / "results.sarif").read_text()
        self.assertNotIn(token, report + result.stdout + result.stderr)
        self.assertTrue(json.loads(report)["runs"][0]["results"])
        # Existing adjudicated fingerprints must still be honored.
        (self.repo / ".gitleaksignore").write_text(f"{secret_commit}:credential.txt:github-pat:1\n")
        self.assertEqual(self.run_scan("push", {"before": self.base, "after": last}, last).returncode, 0)

    def test_pr_merge_resolution_secret_is_detected(self):
        self.git("checkout", "-q", "-b", "feature")
        head = self.commit("feature.txt", "feature\n", "feature")
        self.git("checkout", "-q", "main")
        self.git("merge", "--no-ff", "--no-commit", "-q", head)
        token = "gh" + "p_" + "".join(
            secrets.SystemRandom().sample(string.ascii_letters + string.digits, 36)
        )
        merged = self.commit("merge-only.txt", f'fixture = "{token}"\n', "merge resolution")
        result = self.run_scan("pull_request", self.pr_event(head), merged)
        self.assertEqual(result.returncode, 2)
        self.assertNotIn(token, (self.repo / "results.sarif").read_text() + result.stdout + result.stderr)

    def test_side_branch_secret_is_detected_after_merge(self):
        self.git("checkout", "-q", "-b", "feature")
        self.commit("feature.txt", "feature\n", "feature")
        self.git("checkout", "-q", "-b", "side", self.base)
        token = "gh" + "p_" + "".join(
            secrets.SystemRandom().sample(string.ascii_letters + string.digits, 36)
        )
        side = self.commit("side-secret.txt", f'fixture = "{token}"\n', "side credential")
        self.git("checkout", "-q", "feature")
        self.git("merge", "--no-ff", "-q", side, "-m", "merge side")
        head = self.git("rev-parse", "HEAD")
        merged = self.merge(head)
        result = self.run_scan("pull_request", self.pr_event(head), merged)
        self.assertEqual(result.returncode, 2)
        self.assertNotIn(token, result.stdout + result.stderr)

    def test_missing_configuration_fails_closed(self):
        (self.repo / ".gitleaks.toml").unlink()
        result = self.run_scan("push", {"before": "0" * 40, "after": self.base}, self.base)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("required project .gitleaks.toml is missing", result.stderr)


if __name__ == "__main__":
    unittest.main()
