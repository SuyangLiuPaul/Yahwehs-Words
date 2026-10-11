"""Read-only guard: protect existing pending Microsoft submissions."""
import json
import os
import sys
import urllib.parse
import urllib.request


def may_create_draft(application):
    return not application.get("pendingApplicationSubmission")


def main():
    data = urllib.parse.urlencode({
        "grant_type": "client_credentials", "client_id": os.environ["MS_CLIENT"],
        "client_secret": os.environ["MS_SECRET"],
        "resource": "https://manage.devcenter.microsoft.com",
    }).encode()
    token_url = "https://login.microsoftonline.com/" + os.environ["MS_TENANT"] + "/oauth2/token"
    with urllib.request.urlopen(urllib.request.Request(token_url, data=data), timeout=30) as res:
        token = json.load(res)["access_token"]
    product = "9NVJ28XSKP67"
    req = urllib.request.Request("https://manage.devcenter.microsoft.com/v1.0/my/applications/" + product,
        headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(req, timeout=30) as res:
        app = json.load(res)
    if app.get("id") != product:
        raise SystemExit("Application identity mismatch")
    if "--check-only" in sys.argv:
        pending = app.get("pendingApplicationSubmission")
        if "--verify-staged" in sys.argv and not pending:
            raise SystemExit("Expected staged draft missing; verification failed")
        result = {"app": product, "auth": "verified", "pending": bool(pending)}
        if pending:
            submission_id = pending["id"]
            req = urllib.request.Request(
                "https://manage.devcenter.microsoft.com/v1.0/my/applications/" + product
                + "/submissions/" + submission_id,
                headers={"Authorization": "Bearer " + token})
            with urllib.request.urlopen(req, timeout=30) as res:
                submission = json.load(res)
            result.update({"submission": submission_id, "status": submission.get("status"),
                "packages": [{k: package.get(k) for k in
                    ("id", "fileName", "fileStatus", "version", "architecture")}
                    for package in submission.get("applicationPackages", [])]})
            if "--verify-staged" in sys.argv:
                from ms_verify_staged import verify_staged
                result["stagedStorage"] = verify_staged(submission, product)
        # Explicit allowlist: upload URLs, token and listing contents stay private.
        print(json.dumps(result))
        return
    if not may_create_draft(app):
        raise SystemExit("Existing pending submission preserved; upload stopped")
    print("App access verified; no pending submission. Draft upload may proceed.")


if __name__ == "__main__":
    # Never print response bodies: they can contain upload URLs or credentials.
    try:
        main()
    except urllib.error.HTTPError as error:
        raise SystemExit("Microsoft API HTTP " + str(error.code)) from None
    except (urllib.error.URLError, OSError):
        raise SystemExit("Microsoft read-only request failed; sensitive endpoint omitted") from None
