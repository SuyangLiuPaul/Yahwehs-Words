import unittest
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path
from windows_store_guard import may_create_draft
from windows_store_upload import verify_package, package_payload, confirm_saved_package
from play_store_upload import append_draft, normalize_play_release_notes, wear_track_name

SPEC = "version: 1.7.17\nmsix_config:\n  identity_name: Test.App\n  publisher: CN=TEST\n"

class GuardTests(unittest.TestCase):
    def test_staged_storage_rejects_changed_draft_before_network(self):
        from ms_verify_staged import verify_staged
        from unittest.mock import patch
        with patch("urllib.request.urlopen") as network:
            with self.assertRaises(SystemExit):
                verify_staged({"id": "other", "status": "PendingCommit"}, "9NVJ28XSKP67")
            network.assert_not_called()
    def test_staged_storage_rejects_untrusted_url_before_network(self):
        from ms_verify_staged import verify_staged
        from unittest.mock import patch
        with patch("urllib.request.urlopen") as network:
            with self.assertRaises(SystemExit):
                verify_staged({"id": "1152921505702093995", "status": "PendingCommit",
                    "fileUploadUrl": "https://untrusted.example/package?sig=fixture"}, "9NVJ28XSKP67")
            network.assert_not_called()
    def test_staged_storage_verifies_zip_msix_and_read_only_requests(self):
        import io, hashlib, base64
        import ms_verify_staged as staged
        from unittest.mock import patch
        msix = io.BytesIO()
        manifest = '<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"><Identity Name="YahwehsPeople.YahwehsWords" Publisher="CN=C4997401-2CEE-44B6-9803-4775768C89A5" Version="1.7.17.0" ProcessorArchitecture="x64" /></Package>'
        with zipfile.ZipFile(msix, "w") as archive:
            archive.writestr("AppxManifest.xml", manifest)
        data = msix.getvalue()
        container = io.BytesIO()
        with zipfile.ZipFile(container, "w") as archive:
            archive.writestr("yahwehs_words.msix", data)
        blob = container.getvalue()
        md5 = base64.b64encode(hashlib.md5(blob, usedforsecurity=False).digest()).decode()
        class Response(io.BytesIO):
            status = 200
            headers = {"Content-Length": str(len(blob)), "Content-MD5": md5}
        fixture = {"9NVJ28XSKP67": ("yahwehs_words.msix", len(data), hashlib.sha256(data).hexdigest(), "YahwehsPeople.YahwehsWords", "draft")}
        submission = {"id": "draft", "status": "PendingCommit", "fileUploadUrl": "https://fixture.blob.core.windows.net/blob?sig=fixture"}
        with patch.dict(staged.EXPECTED, fixture), patch("urllib.request.urlopen", side_effect=[Response(), Response(blob)]) as network:
            result = staged.verify_staged(submission, "9NVJ28XSKP67")
            self.assertTrue(result["verified"])
            self.assertTrue(result["contentMD5Matched"])
            self.assertEqual(result["zipSHA256"], hashlib.sha256(blob).hexdigest())
            head = network.call_args_list[0].args[0]
            self.assertEqual(head.get_method(), "HEAD")
            self.assertFalse(head.has_header("Authorization"))
            self.assertIsInstance(network.call_args_list[1].args[0], str)
        with patch.dict(staged.EXPECTED, fixture), patch("urllib.request.urlopen", side_effect=[Response(), Response(blob + b"wrong")]):
            with self.assertRaises(SystemExit):
                staged.verify_staged(submission, "9NVJ28XSKP67")
    def test_existing_ms_commit_requires_explicit_flag_and_automatic_policy(self):
        import io, json
        import windows_store_commit_existing as commit
        from unittest.mock import patch
        expected = commit.EXPECTED[commit.product]
        app = {"id": commit.product, "packageIdentityName": expected[3], "pendingApplicationSubmission": {"id": expected[4]}}
        draft = {"id": expected[4], "status": "PendingCommit", "targetPublishMode": "Immediate"}
        env = {"MS_CLIENT": "fixture", "MS_SECRET": "fixture", "MS_TENANT": "fixture"}
        with patch("sys.stdout", new=io.StringIO()), patch.dict(os.environ, env), patch("sys.argv", ["commit"]), patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps({"access_token": "fixture"}).encode())), patch.object(commit, "request", side_effect=[app, draft]) as api, patch.object(commit, "verify_staged", return_value={"verified": True}):
            commit.main()
            self.assertEqual(api.call_count, 2)
        changed = {**draft, "targetPublishMode": "Manual"}
        with patch("sys.stdout", new=io.StringIO()), patch.dict(os.environ, env), patch("sys.argv", ["commit", "--submit-for-review"]), patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps({"access_token": "fixture"}).encode())), patch.object(commit, "request", side_effect=[app, changed]) as api, patch.object(commit, "verify_staged", return_value={"verified": True}):
            with self.assertRaises(SystemExit):
                commit.main()
            self.assertEqual(api.call_count, 2)
    def test_existing_ms_commit_preserves_submission_and_sends_no_body(self):
        import io, json
        import windows_store_commit_existing as commit
        from unittest.mock import patch
        expected = commit.EXPECTED[commit.product]
        app = {"id": commit.product, "packageIdentityName": expected[3], "pendingApplicationSubmission": {"id": expected[4]}}
        draft = {"id": expected[4], "status": "PendingCommit", "targetPublishMode": "Immediate"}
        with patch("sys.stdout", new=io.StringIO()), patch.dict(os.environ, {"MS_CLIENT": "fixture", "MS_SECRET": "fixture", "MS_TENANT": "fixture"}), patch("sys.argv", ["commit", "--submit-for-review"]), patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps({"access_token": "fixture"}).encode())), patch.object(commit, "request", side_effect=[app, draft, {"status": "CommitStarted"}, {"status": "PreProcessing"}]) as api, patch.object(commit, "verify_staged", return_value={"verified": True}):
            commit.main()
            self.assertEqual(api.call_args_list[2].args[1:3], ("POST", None))
            self.assertTrue(api.call_args_list[2].args[0].endswith('/' + expected[4] + '/commit'))
    def test_existing_ms_commit_never_repeats_progressed_submission(self):
        import io, json
        import windows_store_commit_existing as commit
        from unittest.mock import patch
        expected = commit.EXPECTED[commit.product]
        app = {"id": commit.product, "packageIdentityName": expected[3], "pendingApplicationSubmission": {"id": expected[4]}}
        with patch("sys.stdout", new=io.StringIO()), patch.dict(os.environ, {"MS_CLIENT": "fixture", "MS_SECRET": "fixture", "MS_TENANT": "fixture"}), patch("sys.argv", ["commit", "--submit-for-review"]), patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps({"access_token": "fixture"}).encode())), patch.object(commit, "request", side_effect=[app, {"id": expected[4], "status": "Certification"}]) as api, patch.object(commit, "verify_staged") as storage:
            commit.main()
            self.assertEqual(api.call_count, 2)
            storage.assert_not_called()
    def test_existing_ms_commit_rejects_other_pending_draft(self):
        import io, json
        import windows_store_commit_existing as commit
        from unittest.mock import patch
        expected = commit.EXPECTED[commit.product]
        wrongs = [
            {"id": commit.product, "packageIdentityName": expected[3], "pendingApplicationSubmission": {"id": "other-draft"}},
            {"id": "other-product", "packageIdentityName": expected[3]},
            {"id": commit.product, "packageIdentityName": "Other.Identity"},
        ]
        for wrong in wrongs:
            with patch("sys.stdout", new=io.StringIO()), patch.dict(os.environ, {"MS_CLIENT": "fixture", "MS_SECRET": "fixture", "MS_TENANT": "fixture"}), patch("sys.argv", ["commit", "--submit-for-review"]), patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps({"access_token": "fixture"}).encode())), patch.object(commit, "request", return_value=wrong) as api:
                with self.assertRaises(SystemExit):
                    commit.main()
                self.assertEqual(api.call_count, 1)
    def test_existing_ms_commit_stops_after_storage_hash_mismatch(self):
        import io, json
        import windows_store_commit_existing as commit
        from unittest.mock import patch
        expected = commit.EXPECTED[commit.product]
        app = {"id": commit.product, "packageIdentityName": expected[3], "pendingApplicationSubmission": {"id": expected[4]}}
        draft = {"id": expected[4], "status": "PendingCommit", "targetPublishMode": "Immediate"}
        with patch("sys.stdout", new=io.StringIO()), patch.dict(os.environ, {"MS_CLIENT": "fixture", "MS_SECRET": "fixture", "MS_TENANT": "fixture"}), patch("sys.argv", ["commit", "--submit-for-review"]), patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps({"access_token": "fixture"}).encode())), patch.object(commit, "request", side_effect=[app, draft]) as api, patch.object(commit, "verify_staged", side_effect=SystemExit("Staged MSIX SHA256 mismatch")):
            with self.assertRaises(SystemExit):
                commit.main()
            self.assertEqual(api.call_count, 2)
    def test_no_pending(self):
        self.assertTrue(may_create_draft({"pendingApplicationSubmission": None}))
    def test_preserve_pending(self):
        self.assertFalse(may_create_draft({"pendingApplicationSubmission": {"id": "123"}}))
    def test_play_preserves_existing_release_and_notes(self):
        track = {"track": "internal", "releases": [{"status": "completed", "versionCodes": ["16"], "releaseNotes": [{"language": "en-US", "text": "Old notes"}]}]}
        updated = append_draft(track, 17, "1.7.17", [{"language": "en-US", "text": "New notes"}])
        self.assertEqual(updated["releases"][0], track["releases"][0])
        self.assertEqual(len(track["releases"]), 1)
        self.assertEqual(updated["releases"][1]["status"], "draft")

    def test_wear_release_uses_dedicated_form_factor_track(self):
        self.assertEqual(wear_track_name("internal"), "wear:internal")
        self.assertEqual(wear_track_name("alpha"), "wear:alpha")
        with self.assertRaises(ValueError):
            wear_track_name("production")
    def test_play_existing_draft_is_preserved(self):
        with self.assertRaises(ValueError):
            append_draft({"releases": [{"status": "draft"}]}, 17, "1.7.17")
    def test_windows_official_package_schema_and_readback(self):
        original = {"applicationPackages": [{"fileName": "old.msix"}], "listings": {"en-us": {"baseListing": {"description": "Keep copy"}}}}
        updated = package_payload(original, "new.msix")
        self.assertNotIn("appPackages", updated)
        self.assertEqual(updated["listings"], original["listings"])
        self.assertEqual(len(original["applicationPackages"]), 1)
        record = confirm_saved_package(updated, "new.msix")
        self.assertEqual(record["minimumDirectXVersion"], "None")
        self.assertEqual(record["minimumSystemRam"], "None")
        with self.assertRaises(ValueError):
            confirm_saved_package(original, "new.msix")
    def test_windows_cloned_filename_selects_only_new_pending_entry(self):
        pending = {"fileName": "same.msix", "fileStatus": "PendingUpload"}
        old = {"fileName": "same.msix", "fileStatus": "Uploaded", "version": "1.7.16.0"}
        self.assertEqual(confirm_saved_package({"applicationPackages": [old, pending]}, "same.msix"), pending)
        with self.assertRaises(ValueError):
            confirm_saved_package({"applicationPackages": [pending, pending]}, "same.msix")
        with self.assertRaises(ValueError):
            confirm_saved_package({"applicationPackages": [old]}, "same.msix")
    def test_apple_validation_failure_never_uploads(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            keys = root / ".appstoreconnect/private_keys"
            keys.mkdir(parents=True)
            (keys / "AuthKey_TEST.p8").write_text("dummy fixture, not a credential")
            package = root / "App.ipa"
            package.write_bytes(b"fixture")
            fake = root / "xcrun"
            fake.write_text('#!/bin/sh\nif [ "$2" = "--help" ]; then echo "altool --validate-app <file>"; exit 0; fi\nprintf "%s\\n" "$2" >> "$TEST_LOG"\nif [ "$2" = "--validate-app" ]; then exit 5; fi\nexit 0\n')
            fake.chmod(0o700)
            log = root / "commands.log"
            env = {**os.environ, "HOME": str(root), "PATH": str(root) + ":" + os.environ["PATH"],
                "ASC_KEY_ID": "TEST", "ASC_ISSUER_ID": "TEST", "TEST_LOG": str(log)}
            result = subprocess.run(["bash", str(Path(__file__).with_name("apple_upload.sh")), "ios", str(package)], env=env, capture_output=True)
            self.assertEqual(result.returncode, 5)
            self.assertEqual(log.read_text().splitlines(), ["--validate-app"])
    def test_package_identity_and_version(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "test.msix"
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("AppxManifest.xml", '<Package xmlns="urn:test"><Identity Name="Test.App" Publisher="CN=TEST" Version="1.7.17.0" ProcessorArchitecture="x64" /></Package>')
            self.assertEqual(verify_package(package, SPEC), "Test.App")
            for original, wrong in [("1.7.17", "1.7.16"), ("Test.App", "Wrong.App"), ("CN=TEST", "CN=WRONG")]:
                with self.assertRaises(ValueError):
                    verify_package(package, SPEC.replace(original, wrong))

class UnicodeConfigurationTests(unittest.TestCase):
    def test_uploaders_read_configuration_as_utf8(self):
        import ast
        from pathlib import Path
        for name in ['windows_store_upload.py', 'play_store_upload.py']:
            tree = ast.parse((Path(__file__).parent / name).read_text(encoding='utf-8'))
            reads = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == 'read_text']
            self.assertTrue(reads)
            for node in reads:
                self.assertTrue(any(k.arg == 'encoding' and isinstance(k.value, ast.Constant) and k.value.value == 'utf-8' for k in node.keywords))

class MicrosoftRequestTests(unittest.TestCase):
    def test_create_submission_has_no_json_body(self):
        import ast
        tree = ast.parse((Path(__file__).parent / 'windows_store_upload.py').read_text(encoding='utf-8'))
        posts = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == 'request' and len(n.args) == 4 and isinstance(n.args[1], ast.Constant) and n.args[1].value == 'POST']
        self.assertEqual(len(posts), 1)
        self.assertIsNone(posts[0].args[2].value)

class PlayIsolationTests(unittest.TestCase):
    def test_play_release_notes_normalize_repo_locale_map(self):
        notes = normalize_play_release_notes({
            "en-us": " English ", "zh-hans": "简体中文", "zh-hant": "繁體中文"})
        self.assertEqual(notes, [
            {"language": "en-US", "text": "English"},
            {"language": "zh-CN", "text": "简体中文"},
            {"language": "zh-TW", "text": "繁體中文"},
        ])

    def test_play_release_notes_accept_api_records_and_reject_missing_locale(self):
        notes = normalize_play_release_notes([
            {"language": "zh-TW", "text": "繁體"},
            {"language": "en-US", "text": "English"},
            {"language": "zh-CN", "text": "简体"},
        ])
        self.assertEqual([note["language"] for note in notes],
                         ["en-US", "zh-CN", "zh-TW"])
        with self.assertRaisesRegex(ValueError, "missing languages"):
            normalize_play_release_notes({"en-us": "English"})

    def test_workflows_serialize_play_edits(self):
        from pathlib import Path
        root = Path(__file__).parent.parent
        for name in ['play-aab.yml', 'store-api-preflight.yml', 'store-play-recover-draft.yml']:
            text = (root / '.github/workflows' / name).read_text(encoding='utf-8')
            self.assertIn('group: store-play-edit-${{ github.repository }}', text)
            self.assertIn('cancel-in-progress: false', text)
    def test_commit_never_sends_or_cancels_review(self):
        from pathlib import Path
        text = (Path(__file__).parent / 'play_store_upload.py').read_text(encoding='utf-8')
        self.assertIn('params["changesNotSentForReview"] = "true"', text)
        self.assertIn('"changesInReviewBehavior": "ERROR_IF_IN_REVIEW"', text)

if __name__ == "__main__":
    unittest.main()
