"""Create-only draft upload. No DELETE, commit, review or certification API."""
import json
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
    with urllib.request.urlopen(urllib.request.Request(url, data=data, method=method, headers=h), timeout=60) as res:
        return json.load(res)


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


def main():
    paths = list(Path("build/windows/x64/runner/Release").glob("*.msix"))
    if len(paths) != 1:
        raise SystemExit("Expected exactly one MSIX")
    identity = verify_package(paths[0], Path("pubspec.yaml").read_text())
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
    submission = request(base + "/submissions", "POST", {}, headers)
    submission_id = submission["id"]
    print("Created draft " + submission_id + "; certification not submitted")
    package_name = paths[0].name
    with tempfile.TemporaryDirectory() as directory:
        archive = Path(directory) / "packages.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            bundle.write(paths[0], package_name)
        req = urllib.request.Request(submission["fileUploadUrl"], data=archive.read_bytes(),
            method="PUT", headers={"x-ms-blob-type": "BlockBlob", "Content-Type": "application/zip"})
        with urllib.request.urlopen(req, timeout=600) as response:
            if response.status != 201:
                raise SystemExit("Package storage did not accept upload")
    # Preserve existing listing/localization/pricing fields verbatim.
    submission.setdefault("appPackages", []).append({"fileName": package_name, "fileStatus": "PendingUpload"})
    updated = request(base + "/submissions/" + submission_id, "PUT", submission, headers)
    if updated.get("id") != submission_id:
        raise SystemExit("Draft save identity mismatch")
    print("Package uploaded and draft saved. Store validation, review and publication not claimed.")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        raise SystemExit("Microsoft API HTTP " + str(error.code) + "; existing draft retained") from None
