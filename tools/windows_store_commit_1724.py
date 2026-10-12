"""Verify the exact retained 1.7.24 MSIX staged by the API draft, update only localized release notes, then submit it."""
import argparse
import hashlib
import json
import os
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

PRODUCT = "9NVJ28XSKP67"
DRAFT = "1152921505702102644"
PACKAGE = "yahwehs_words.msix"
EXPECTED_SHA256 = "983b09408f911af27dcfd51822c7afd2559d4bd061b559f870b9d7e7a6f96477"
IDENTITY = "YahwehsPeople.YahwehsWords"
VERSION = "1.7.24.0"
PUBLISHER = "CN=C4997401-2CEE-44B6-9803-4775768C89A5"
NOTES = json.loads(Path("docs/microsoft-store-release-notes-1.7.24.json").read_text(encoding="utf-8"))
BASE = "https://manage.devcenter.microsoft.com/v1.0/my/applications/" + PRODUCT


def api(url, method="GET", payload=None, headers=None):
    body = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(url, data=body, method=method,
        headers={"Content-Type": "application/json", **(headers or {})})
    safe_path = urllib.parse.urlsplit(url).path
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            data = response.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        raise SystemExit("Microsoft API " + method + " " + safe_path + " returned HTTP " + str(error.code)) from None
    except urllib.error.URLError:
        raise SystemExit("Microsoft API " + method + " " + safe_path + " network request failed") from None


def token():
    form = urllib.parse.urlencode({"grant_type": "client_credentials", "client_id": os.environ["MS_CLIENT"],
        "client_secret": os.environ["MS_SECRET"], "resource": "https://manage.devcenter.microsoft.com"}).encode()
    url = "https://login.microsoftonline.com/" + os.environ["MS_TENANT"] + "/oauth2/token"
    with urllib.request.urlopen(urllib.request.Request(url, data=form), timeout=30) as response:
        return json.load(response)["access_token"]


def verify_staged(submission):
    if submission.get("id") != DRAFT or submission.get("status") != "PendingCommit":
        raise SystemExit("The exact expected draft is no longer pending commit")
    packages = [p for p in submission.get("applicationPackages", [])
        if p.get("fileName") == PACKAGE and p.get("fileStatus") == "PendingUpload"]
    if len(packages) != 1:
        raise SystemExit("Expected exactly one new PendingUpload package entry")
    url = submission.get("fileUploadUrl", "")
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not (parsed.hostname or "").endswith(".blob.core.windows.net"):
        raise SystemExit("Microsoft draft returned an unexpected package storage host")
    try:
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60) as response:
            length = int(response.headers.get("Content-Length", "0"))
            head_status = response.status
    except (urllib.error.HTTPError, urllib.error.URLError, OSError):
        raise SystemExit("The exact staged Microsoft package is not downloadable; draft preserved") from None
    if not 0 < length < 512 * 1024 * 1024:
        raise SystemExit("Staged package archive length is missing or outside expected bounds")
    with tempfile.TemporaryFile() as archive_file:
        digest = hashlib.sha256()
        count = 0
        try:
            with urllib.request.urlopen(url, timeout=600) as response:
                get_status = response.status
                while block := response.read(1024 * 1024):
                    count += len(block)
                    if count > length:
                        raise SystemExit("Staged ZIP exceeded its declared size")
                    digest.update(block)
                    archive_file.write(block)
        except (urllib.error.HTTPError, urllib.error.URLError, OSError):
            raise SystemExit("The exact staged Microsoft package download failed; draft preserved") from None
        if count != length:
            raise SystemExit("Staged ZIP size changed during download")
        archive_file.seek(0)
        with zipfile.ZipFile(archive_file) as archive:
            entries = [item for item in archive.infolist() if not item.is_dir()]
            if len(entries) != 1 or entries[0].filename != PACKAGE:
                raise SystemExit("Staged ZIP must contain only the exact expected MSIX")
            with archive.open(PACKAGE) as package_file:
                package_hash = hashlib.sha256()
                package_bytes = tempfile.TemporaryFile()
                try:
                    while block := package_file.read(1024 * 1024):
                        package_hash.update(block)
                        package_bytes.write(block)
                    if package_hash.hexdigest() != EXPECTED_SHA256:
                        raise SystemExit("Staged MSIX SHA-256 does not match the delivery record")
                    package_bytes.seek(0)
                    with zipfile.ZipFile(package_bytes) as msix:
                        root = ET.fromstring(msix.read("AppxManifest.xml"))
                    identity = root.find("{http://schemas.microsoft.com/appx/manifest/foundation/windows10}Identity")
                    if identity is None:
                        raise SystemExit("Staged MSIX has no package identity")
                    actual = (identity.get("Name"), identity.get("Version"), identity.get("ProcessorArchitecture"), identity.get("Publisher"))
                    if actual != (IDENTITY, VERSION, "x64", PUBLISHER):
                        raise SystemExit("Staged MSIX identity/version/architecture/publisher mismatch")
                finally:
                    package_bytes.close()
    return {"submission": DRAFT, "storageHeadStatus": head_status, "storageGetStatus": get_status,
        "zipBytes": count, "zipSha256": digest.hexdigest(), "package": PACKAGE,
        "packageSha256": EXPECTED_SHA256, "identity": IDENTITY, "version": VERSION,
        "architecture": "x64", "stagedVerified": True}


def update_notes(submission, headers):
    listings = submission.get("listings") or {}
    if not set(NOTES).issubset({key.lower() for key in listings}):
        raise SystemExit("Draft does not contain all three expected listing locales; no commit")
    for key, listing in listings.items():
        locale = key.lower()
        if locale in NOTES:
            base_listing = listing.get("baseListing")
            if not isinstance(base_listing, dict):
                raise SystemExit("A localized baseListing is missing; no commit")
            base_listing["releaseNotes"] = NOTES[locale]
    updated = api(BASE + "/submissions/" + DRAFT, "PUT", submission, headers)
    if updated.get("id") != DRAFT:
        raise SystemExit("Microsoft release-notes readback returned a different submission")
    verified = api(BASE + "/submissions/" + DRAFT, headers=headers)
    for key, listing in verified.get("listings", {}).items():
        if key.lower() in NOTES and (listing.get("baseListing") or {}).get("releaseNotes") != NOTES[key.lower()]:
            raise SystemExit("Localized release-notes readback mismatch; no commit")
    return sorted(key.lower() for key in verified.get("listings", {}) if key.lower() in NOTES)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--submit-for-review", action="store_true")
    args = parser.parse_args()
    headers = {"Authorization": "Bearer " + token()}
    app = api(BASE, headers=headers)
    if app.get("id") != PRODUCT or app.get("packageIdentityName") != IDENTITY:
        raise SystemExit("Microsoft Store application identity mismatch")
    pending = app.get("pendingApplicationSubmission")
    if not pending or pending.get("id") != DRAFT:
        raise SystemExit("Another or no pending submission found; preserve it and stop")
    submission_url = BASE + "/submissions/" + DRAFT
    submission = api(submission_url, headers=headers)
    if submission.get("targetPublishMode") != "Immediate":
        raise SystemExit("Automatic publication setting changed; preserve it and stop")
    staged = verify_staged(submission)
    print(json.dumps({**staged, "reviewSubmitted": False}))
    if not args.submit_for_review:
        print("Read-only staged-package validation complete; certification not submitted")
        return
    locales = update_notes(submission, headers)
    api(submission_url + "/commit", "POST", None, headers)
    status = api(submission_url + "/status", headers=headers)
    print(json.dumps({"submission": DRAFT, "status": status.get("status"),
        "automaticPublication": True, "packageVersion": VERSION,
        "releaseNoteLocalesVerified": locales, "published": status.get("status") == "Published"}))


if __name__ == "__main__":
    main()
