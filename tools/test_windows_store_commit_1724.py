"""Refusal and read-only checks for the exact retained 1.7.24 draft."""
import copy
import sys
import unittest
from unittest.mock import patch

import windows_store_commit_1724 as release


class SubmitGuards(unittest.TestCase):
    def setUp(self):
        self.app = {"id": release.PRODUCT,
                    "packageIdentityName": release.IDENTITY,
                    "pendingApplicationSubmission": {"id": release.DRAFT}}
        self.submission = {"id": release.DRAFT, "status": "PendingCommit",
                           "targetPublishMode": "Immediate"}

    def run_main(self, app=None, submission=None, submit=False, storage_error=False):
        app = self.app if app is None else app
        submission = self.submission if submission is None else submission
        responses = [app, submission]
        with patch.object(sys, "argv", ["guard"] + (["--submit-for-review"] if submit else [])), \
             patch.object(release, "token", return_value="test"), \
             patch.object(release, "api", side_effect=responses) as api, \
             patch.object(release, "verify_staged", side_effect=SystemExit("storage changed") if storage_error else None,
                          return_value={"stagedVerified": True}) as verify, \
             patch.object(release, "update_notes") as update:
            try:
                release.main()
            except SystemExit:
                if not storage_error and app == self.app and submission == self.submission:
                    raise
            self.assertTrue(all(len(call.args) == 1 for call in api.call_args_list))
            update.assert_not_called()
            return verify.call_count

    def test_read_only_does_not_update_notes_or_commit(self):
        self.assertEqual(self.run_main(), 1)

    def test_changed_pending_submission_is_preserved(self):
        app = copy.deepcopy(self.app)
        app["pendingApplicationSubmission"]["id"] = "new-owner-draft"
        self.assertEqual(self.run_main(app=app, submit=True), 0)

    def test_changed_application_identity_refuses_commit(self):
        app = {**self.app, "packageIdentityName": "another.app"}
        self.assertEqual(self.run_main(app=app, submit=True), 0)

    def test_changed_publication_policy_refuses_commit(self):
        draft = {**self.submission, "targetPublishMode": "Manual"}
        self.assertEqual(self.run_main(submission=draft, submit=True), 0)

    def test_storage_verification_failure_refuses_notes_and_commit(self):
        self.assertEqual(self.run_main(submit=True, storage_error=True), 1)

    def test_actual_staged_guard_refuses_wrong_draft_and_state(self):
        for change in [{"id": "another-draft"}, {"status": "Certification"}]:
            with self.subTest(change=change), self.assertRaises(SystemExit):
                release.verify_staged({**self.submission, **change})

    def test_actual_staged_guard_refuses_unknown_storage_host(self):
        draft = {**self.submission,
                 "applicationPackages": [{"fileName": release.PACKAGE, "fileStatus": "PendingUpload"}],
                 "fileUploadUrl": "https://unexpected.example/package.zip"}
        with self.assertRaises(SystemExit):
            release.verify_staged(draft)


if __name__ == "__main__":
    unittest.main()
