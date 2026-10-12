"""Upload phone and optional Wear AABs to a guarded Play test-track release."""
import copy
import hashlib
import json
import os
import sys
from pathlib import Path
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

package = "com.yahwehword.words"


def append_release(track, code, name, notes, status):
    result = copy.deepcopy(track)
    releases = result.get("releases", [])
    if any(r.get("status") in {"draft", "inProgress", "halted"} for r in releases):
        raise ValueError("Existing draft or active release preserved; stop before upload")
    codes = code if isinstance(code, (list, tuple)) else [code]
    release = {"name": name, "status": status,
        "versionCodes": [str(item) for item in codes], "releaseNotes": notes}
    if status == "completed":
        if track.get("track") != "internal":
            raise ValueError("Direct publication is restricted to the internal track")
        result["releases"] = [release]
    else:
        result.setdefault("releases", []).append(release)
    return result


def append_draft(track, code, name, notes=None):
    """Backward-compatible helper used by existing release-guard tests."""
    return append_release(track, code, name, notes or [], "draft")


def main():
    if len(sys.argv) not in {3, 4}:
        raise SystemExit("Usage: play_store_upload.py TRACK PHONE_AAB [WEAR_AAB]")
    track_name, phone_file, *wear_files = sys.argv[1:]
    files = [phone_file, *wear_files]
    if track_name not in {"internal", "alpha", "beta"}:
        raise SystemExit("Only test tracks are allowed")
    release_status = os.environ.get("RELEASE_STATUS", "draft")
    if release_status not in {"draft", "completed"} or (release_status == "completed" and track_name != "internal"):
        raise SystemExit("Only draft releases or an explicitly authorized internal release are supported")
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
        append_release(track, 0, "preflight", [], release_status)  # Refuse existing draft/active release before upload.
        library = read(session.get(base + "/" + edit + "/bundles", timeout=30))
        existing_codes = [int(b["versionCode"]) for b in library.get("bundles", [])]
        recovery_code = os.environ.get("PLAY_REUSE_VERSION_CODE")
        if recovery_code and len(files) != 1:
            raise SystemExit("Retained-package recovery accepts exactly one AAB")
        uploaded_codes = []
        upload_records = []
        for file in files:
            uploaded = None
            if recovery_code:
                uploaded = next((b for b in library.get("bundles", []) if str(b["versionCode"]) == recovery_code), None)
                print(json.dumps({"recoveryVersionCode": recovery_code, "alreadyInBundleLibrary": uploaded is not None}))
                if uploaded is None and os.environ.get("ALLOW_MISSING_BUNDLE_UPLOAD") != "true":
                    raise SystemExit("Bundle absent from committed library; explicit retained-package recovery required")
            if uploaded is None:
                with Path(file).open("rb") as bundle:
                    uploaded = read(session.post(
                        "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/" + package + "/edits/" + edit + "/bundles?uploadType=media",
                        data=bundle, headers={"Content-Type": "application/octet-stream"}, timeout=600))
            code = int(uploaded["versionCode"])
            if recovery_code and str(code) != recovery_code:
                raise SystemExit("Recovery package version code mismatch")
            if (not recovery_code and code <= max(existing_codes, default=0)) or code in uploaded_codes:
                raise SystemExit("Every new AAB version code must exceed all existing Play bundles and each other")
            digest = hashlib.file_digest(Path(file).open("rb"), "sha256").hexdigest()
            if uploaded.get("sha256", "").lower() != digest:
                raise SystemExit("Uploaded bundle SHA-256 mismatch or unavailable")
            uploaded_codes.append(code)
            upload_records.append({"file": Path(file).name, "versionCode": code, "sha256": digest})
        print(json.dumps({"package": package, "bundles": upload_records,
            "sourceSha": os.environ.get("PACKAGE_SOURCE_SHA", os.environ.get("GITHUB_SHA")), "bundlesAccepted": True}))
        name = Path("pubspec.yaml").read_text(encoding="utf-8").split("\nversion:", 1)[1].splitlines()[0].strip().split("+")[0]
        notes_path = Path("docs/store-notes-" + name + ".json")
        if not notes_path.is_file():
            raise SystemExit("Localized store notes missing for app version " + name)
        notes = json.loads(notes_path.read_text(encoding="utf-8"))
        if not {"en-US", "zh-CN", "zh-TW"}.issubset({item.get("language") for item in notes}):
            raise SystemExit("Release notes must include en-US, zh-CN and zh-TW")
        read(session.put(track_url, json=append_release(track, uploaded_codes, name, notes, release_status), timeout=30))
        read(session.post(base + "/" + edit + ":validate", timeout=30))
        params = {"changesInReviewBehavior": "ERROR_IF_IN_REVIEW"}
        if release_status == "draft":
            params["changesNotSentForReview"] = "true"
        else:
            params["changesNotSentForReview"] = "false"
        read(session.post(base + "/" + edit + ":commit", params=params, timeout=60))
        committed = True
        print(json.dumps({"track": track_name, "releaseStatus": release_status, "versionCodes": uploaded_codes,
            "draftOnly": release_status == "draft", "internalTrackPublicationRequested": release_status == "completed"}))
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
