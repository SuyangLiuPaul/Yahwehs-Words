import unittest
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path
from windows_store_guard import may_create_draft
from windows_store_upload import verify_package, package_payload, confirm_saved_package
from play_store_upload import append_draft

SPEC = "version: 1.7.17\nmsix_config:\n  identity_name: Test.App\n  publisher: CN=TEST\n"

class GuardTests(unittest.TestCase):
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

if __name__ == "__main__":
    unittest.main()
