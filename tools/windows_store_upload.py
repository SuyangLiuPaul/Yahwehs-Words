"""Create-only draft upload. No DELETE, commit, review or certification API."""
import json
import copy
import hashlib
import os
import re
import xml.etree.ElementTree as ET
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from windows_store_guard import may_create_draft

product = "9NVJ28XSKP67"
base = "https://manage.devcenter.microsoft.com/v1.0/my/applications/" + product


def request(url, method="GET", payload=None, headers=None):
    data = None if payload is None else json.dumps(payload).encode()
    h = {"Content-Type": "application/json", **(headers or {})}
    print(json.dumps({"operation": method + " " + urllib.parse.urlsplit(url).path}))
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, method=method, headers=h), timeout=60) as res:
            return json.load(res)
    except urllib.error.HTTPError as error:
        try:
            payload = json.load(error)
            details = payload.get("error", payload)
            message = str(details.get("message", details.get("errorDescription", "No structured API message")))[:800]
            # Do not expose URL queries (including SAS signatures) from an API message.
            message = re.sub(r"(https?://[^\s?]+)\?[^\s]+", r"\1?[redacted]", message)
            code = details.get("code", details.get("errorCode"))
        except (ValueError, AttributeError):
            code, message = None, "No structured API message"
        print(json.dumps({"httpStatus": error.code, "apiCode": code, "apiMessage": message}))
        raise


def verify_package(package, specification):
    def value(key):
        match = re.search(r"^\s*" + key + r":\s*(.+)$", specification, re.M)
        if match is None:
            raise ValueError("Missing package identity configuration")
        return match.group(1).strip().strip("\"'")
    expected = {"Name": value("identity_name"), "Publisher": value("publisher"),
        "Version": value("version").split("+")[0] + ".0", "ProcessorArchitecture": "x64"}
    with zipfile.ZipFile(package) as archive:
        if archive.testzip() is not None:
            raise ValueError("Corrupt MSIX archive")
        identity = ET.fromstring(archive.read("AppxManifest.xml")).find("{*}Identity")
    if identity is None or any(identity.get(k) != v for k, v in expected.items()):
        raise ValueError("MSIX identity, publisher, architecture or version mismatch")
    return identity.get("Name")


def package_payload(submission, filename):
    result = copy.deepcopy(submission)
    result.setdefault("applicationPackages", []).append({
        "fileName": filename, "fileStatus": "PendingUpload",
        "minimumDirectXVersion": "None", "minimumSystemRam": "None"})
    return result


def confirm_saved_package(submission, filename):
    # Cloned submissions retain old Uploaded packages with the same basename.
    # Select the exact new PendingUpload entry; duplicate new entries still fail.
    matches = [p for p in submission.get("applicationPackages", [])
        if p.get("fileName") == filename and p.get("fileStatus") == "PendingUpload"]
    if len(matches) != 1:
        raise ValueError("New package missing or duplicated in read-back submission")
    return matches[0]


def main():
    paths = list(Path("build/windows/x64/runner/Release").glob("*.msix"))
    if len(paths) != 1:
        raise SystemExit("Expected exactly one MSIX")
    identity = verify_package(paths[0], Path("pubspec.yaml").read_text(encoding="utf-8"))
    credentials = urllib.parse.urlencode({"grant_type": "client_credentials",
        "client_id": os.environ["MS_CLIENT"], "client_secret": os.environ["MS_SECRET"],
        "resource": "https://manage.devcenter.microsoft.com"}).encode()
    with urllib.request.urlopen(urllib.request.Request(
        "https://login.microsoftonline.com/" + os.environ["MS_TENANT"] + "/oauth2/token",
        data=credentials), timeout=30) as response:
        token = json.load(response)["access_token"]
    headers = {"Authorization": "Bearer " + token}
    app = request(base, headers=headers)
    if app.get("id") != product or app.get("packageIdentityName") != identity or not may_create_draft(app):
        raise SystemExit("Identity mismatch or existing pending submission; no changes made")
    # Unlike msstore publish, this endpoint is create-only: never delete drafts.
    submission = request(base + "/submissions", "POST", None, headers)
    submission_id = submission["id"]
    print("Created draft " + submission_id + "; certification not submitted")
    package_name = paths[0].name
    submission = package_payload(submission, package_name)
    saved_url = base + "/submissions/" + submission_id
    updated = request(saved_url, "PUT", submission, headers)
    if updated.get("id") != submission_id:
        raise SystemExit("Draft save identity mismatch")
    with tempfile.TemporaryDirectory() as directory:
        archive = Path(directory) / "packages.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            bundle.write(paths[0], package_name)
        req = urllib.request.Request(submission["fileUploadUrl"], data=archive.read_bytes(),
            method="PUT", headers={"x-ms-blob-type": "BlockBlob", "Content-Type": "application/zip"})
        with urllib.request.urlopen(req, timeout=600) as response:
            if response.status != 201:
                raise SystemExit("Package storage did not accept upload")
    verified = request(saved_url, headers=headers)
    saved_package = confirm_saved_package(verified, package_name)
    print(json.dumps({"product": product, "submission": submission_id,
        "sourceSha": os.environ.get("PACKAGE_SOURCE_SHA", os.environ.get("GITHUB_SHA")), "filename": package_name,
        "sha256": hashlib.file_digest(paths[0].open("rb"), "sha256").hexdigest(),
        "draftPackageReadBack": True, "serverPackageVersion": saved_package.get("version"),
        "serverPackageStatus": saved_package.get("fileStatus"), "submissionStatus": verified.get("status"),
        "reviewSubmitted": False, "published": False}))
    print("ZIP accepted and package entry read back. Store processing/validation not claimed.")



if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        raise SystemExit("Microsoft API HTTP " + str(error.code) + "; existing draft retained") from None
