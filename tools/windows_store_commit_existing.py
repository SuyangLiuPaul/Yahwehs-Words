"""Commit only the previously verified 1.7.17 draft after explicit release authorization."""
import argparse
import json
import os
import re
import urllib.parse
import urllib.request
from ms_verify_staged import EXPECTED, verify_staged
from windows_store_upload import product, base, request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--submit-for-review', action='store_true')
    args = parser.parse_args()
    form = urllib.parse.urlencode({'grant_type': 'client_credentials',
        'client_id': os.environ['MS_CLIENT'], 'client_secret': os.environ['MS_SECRET'],
        'resource': 'https://manage.devcenter.microsoft.com'}).encode()
    with urllib.request.urlopen(urllib.request.Request(
        'https://login.microsoftonline.com/' + os.environ['MS_TENANT'] + '/oauth2/token', data=form), timeout=30) as response:
        token = json.load(response)['access_token']
    headers = {'Authorization': 'Bearer ' + token}
    app = request(base, headers=headers)
    expected = EXPECTED[product]
    if app.get('id') != product or app.get('packageIdentityName') != expected[3]:
        raise SystemExit('Application identity mismatch; no commit')
    draft_id = expected[4]
    pending = app.get('pendingApplicationSubmission')
    if pending and pending.get('id') != draft_id:
        raise SystemExit('Different pending submission preserved; no commit')
    submission = request(base + '/submissions/' + draft_id, headers=headers)
    safe = {'product': product, 'submission': draft_id, 'status': submission.get('status'),
        'targetPublishMode': submission.get('targetPublishMode'),
        'targetPublishDate': submission.get('targetPublishDate'),
        'packages': [{k: package.get(k) for k in ('fileName', 'fileStatus', 'version', 'architecture')}
            for package in submission.get('applicationPackages', [])]}
    print(json.dumps(safe))
    if submission.get('id') != draft_id:
        raise SystemExit('Submission identity mismatch')
    if submission.get('status') != 'PendingCommit':
        print('No repeated commit: existing submission already progressed or needs attention.')
        return
    verified = verify_staged(submission, product)
    print(json.dumps({'stagedStorage': verified}))
    if not args.submit_for_review:
        print('Read-only preflight complete; no commit requested.')
        return
    if not pending or submission.get('targetPublishMode') != 'Immediate':
        raise SystemExit('Pending draft or existing automatic publication policy changed; no commit')
    result = request(base + '/submissions/' + draft_id + '/commit', 'POST', None, headers)
    print(json.dumps({'commitResponseStatus': result.get('status'), 'submission': draft_id}))
    status = request(base + '/submissions/' + draft_id + '/status', headers=headers)
    details = status.get('statusDetails') or {}
    issues = [{
        'code': issue.get('code'),
        'details': re.sub(r'https?://\S+', '[URL omitted]', str(issue.get('details', '')))[:800]
    } for issue in details.get('errors', [])]
    print(json.dumps({'submission': draft_id, 'status': status.get('status'),
                     'errors': issues, 'published': status.get('status') == 'Published'}))


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        raise SystemExit('Microsoft API HTTP ' + str(error.code) + '; existing submission preserved') from None
    except (urllib.error.URLError, OSError):
        raise SystemExit('Microsoft network request failed; sensitive endpoint omitted') from None
