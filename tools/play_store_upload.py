"""Upload a phone AAB into a preserved test-track draft, never send review."""
import copy
import hashlib
import json
import os
import sys
from pathlib import Path
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

package = "com.yahwehword.words"


def append_draft(track, code, name, notes=None):
    result = copy.deepcopy(track)
    releases = result.setdefault("releases", [])
    if any(r.get("status") == "draft" for r in releases):
        raise ValueError("Existing draft preserved; stop before upload")
    releases.append({"name": name, "status": "draft", "versionCodes": [str(code)], "releaseNotes": notes or []})
    return result


def main():
    track_name, file = sys.argv[1:]
    if track_name not in {"internal", "alpha", "beta"}:
        raise SystemExit("Only test tracks are allowed")
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
        scopes=["https://www.googleapis.com/auth/androidpublisher"])
    session = AuthorizedSession(creds)
    base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + package + "/edits"
    def read(response):
        if not response.ok:
            try:
                err = response.json().get("error", {})
                message = str(err.get("message", ""))[:800]
            except (ValueError, AttributeError):
                message = "No structured API error"
            print(json.dumps({"operation": response.request.method + " " + response.request.url.split("/edits", 1)[-1].split("?", 1)[0], "httpStatus": response.status_code, "apiMessage": message}))
            raise SystemExit("Play API HTTP " + str(response.status_code))
        return response.json()
    edit = read(session.post(base, json={}, timeout=30))["id"]
    print(json.dumps({"openedOwnEdit": edit}))
    committed = False
    try:
        track_url = base + "/" + edit + "/tracks/" + track_name
        track = read(session.get(track_url, timeout=30))
        append_draft(track, 0, "preflight")  # Refuse any existing draft before upload.
        recovery_code = os.environ.get("PLAY_REUSE_VERSION_CODE")
        uploaded = None
        if recovery_code:
            library = read(session.get(base + "/" + edit + "/bundles", timeout=30))
            uploaded = next((b for b in library.get("bundles", []) if str(b["versionCode"]) == recovery_code), None)
            print(json.dumps({"recoveryVersionCode": recovery_code, "alreadyInBundleLibrary": uploaded is not None}))
            if uploaded is None and os.environ.get("ALLOW_MISSING_BUNDLE_UPLOAD") != "true":
                raise SystemExit("Bundle absent from committed library; explicit retained-package recovery required")
        if uploaded is None:
            with Path(file).open("rb") as bundle:
                uploaded = read(session.post(
                    "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/" + package + "/edits/" + edit + "/bundles?uploadType=media",
                    data=bundle, headers={"Content-Type": "application/octet-stream"}, timeout=600))
        if recovery_code and str(uploaded["versionCode"]) != recovery_code:
            raise SystemExit("Recovery package version code mismatch")
        code = uploaded["versionCode"]
        digest = hashlib.file_digest(Path(file).open("rb"), "sha256").hexdigest()
        if uploaded.get("sha256", "").lower() != digest:
            raise SystemExit("Uploaded bundle SHA-256 mismatch or unavailable")
        print(json.dumps({"package": package, "versionCode": code, "sha256": digest,
            "sourceSha": os.environ.get("PACKAGE_SOURCE_SHA", os.environ.get("GITHUB_SHA")), "bundleAccepted": True}))
        name = Path("pubspec.yaml").read_text(encoding="utf-8").split("\nversion:", 1)[1].splitlines()[0].strip().split("+")[0]
        read(session.put(track_url, json=append_draft(track, code, name, json.loads(Path("docs/store-notes-1.7.17.json").read_text(encoding="utf-8"))), timeout=30))
        read(session.post(base + "/" + edit + ":validate", timeout=30))
        # Never retry with this flag removed, even when the server rejects it.
        read(session.post(base + "/" + edit + ":commit", params={"changesNotSentForReview": "true", "changesInReviewBehavior": "ERROR_IF_IN_REVIEW"}, timeout=60))
        committed = True
        print("Draft saved without sending review; existing releases preserved. Not published.")
    finally:
        if not committed:
            primary_failed = sys.exc_info()[0] is not None
            try:
                response = session.delete(base + "/" + edit, timeout=30)
                print(json.dumps({"ownTemporaryEditCleanupStatus": response.status_code}))
                if response.status_code not in {200, 204, 404} and not primary_failed:
                    raise SystemExit("Temporary edit cleanup HTTP " + str(response.status_code))
            except Exception:
                print("Own temporary edit cleanup network failure")
                if not primary_failed:
                    raise


if __name__ == "__main__":
    main()
