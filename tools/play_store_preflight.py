"""Read tracks and bundles in a temporary edit; never commit a release."""
import json
import os
import requests
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

package = "com.yahwehword.words"
creds = service_account.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
    scopes=["https://www.googleapis.com/auth/androidpublisher"])
session = AuthorizedSession(creds)
base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + package + "/edits"


def read(response):
    if not response.ok:
        raise SystemExit("Play API HTTP " + str(response.status_code))
    return response.json()


edit = read(session.post(base, json={}, timeout=30))["id"]
try:
    tracks = read(session.get(base + "/" + edit + "/tracks", timeout=30))
    bundles = read(session.get(base + "/" + edit + "/bundles", timeout=30))
    result = {"package": package, "auth": "verified",
        "tracks": [{"track": t["track"], "releases": [
            {"name": r.get("name"), "status": r.get("status"), "versionCodes": r.get("versionCodes")}
            for r in t.get("releases", [])]} for t in tracks.get("tracks", [])],
        "bundleVersionCodes": [b["versionCode"] for b in bundles.get("bundles", [])]}
    print(json.dumps(result))
finally:
    response = session.delete(base + "/" + edit, timeout=30)
    if not response.ok:
        raise SystemExit("Temporary edit cleanup HTTP " + str(response.status_code))
