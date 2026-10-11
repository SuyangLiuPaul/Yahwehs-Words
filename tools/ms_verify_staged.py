"""Read-only verification of the existing Microsoft draft's staged ZIP."""
import base64
import hashlib
import tempfile
import urllib.parse
import urllib.request
import zipfile
import xml.etree.ElementTree as ET

EXPECTED = {
    '9NVJ28XSKP67': ('yahwehs_words.msix', 150938366, 'dffa66e355e004382c6727c66daf30341de22ac2c56605f2a348509c35bc71e7', 'YahwehsPeople.YahwehsWords', '1152921505702093995'),
    '9P93XHHFP6H3': ('yahwehs_sword.msix', 151516204, '275b0098b1e7bb20dfccadb7c0d7694a6e333a32fcf4dc56e8686981390985fb', 'YahwehsPeople.YahwehsSword', '1152921505702094507'),
}

def verify_staged(submission, product):
    name, size, digest, identity, draft = EXPECTED[product]
    if submission.get('id') != draft or submission.get('status') != 'PendingCommit':
        raise SystemExit('Expected existing draft changed; no storage read attempted')
    url = submission.get('fileUploadUrl', '')
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != 'https' or not (parsed.hostname or '').endswith('.blob.core.windows.net'):
        raise SystemExit('Unexpected storage endpoint; no request sent')
    # No OAuth header is forwarded to storage. SAS stays in memory, never in output.
    with urllib.request.urlopen(urllib.request.Request(url, method='HEAD'), timeout=60) as response:
        length = int(response.headers['Content-Length'])
        md5 = response.headers.get('Content-MD5')
        head_status = response.status
    if not 0 < length < 512 * 1024 * 1024:
        raise SystemExit('Unexpected staged ZIP length')
    zip_sha = hashlib.sha256()
    zip_md5 = hashlib.md5(usedforsecurity=False)
    with tempfile.TemporaryFile() as storage:
        with urllib.request.urlopen(url, timeout=600) as response:
            get_status = response.status
            while block := response.read(1024 * 1024):
                storage.write(block)
                zip_sha.update(block)
                zip_md5.update(block)
                if storage.tell() > length:
                    raise SystemExit('Staged ZIP exceeds HEAD length')
        if storage.tell() != length:
            raise SystemExit('Staged ZIP length mismatch')
        actual_md5 = base64.b64encode(zip_md5.digest()).decode("ascii")
        if md5 and md5 != actual_md5:
            raise SystemExit("Staged ZIP Content-MD5 mismatch")
        storage.seek(0)
        with zipfile.ZipFile(storage) as archive:
            files = [entry for entry in archive.infolist() if not entry.is_dir()]
            if len(files) != 1 or files[0].filename != name or files[0].file_size != size:
                raise SystemExit('Staged package count/name/size mismatch')
            with archive.open(name) as package:
                data = package.read()
            actual = hashlib.sha256(data).hexdigest()
            if actual != digest:
                raise SystemExit('Staged MSIX SHA256 mismatch')
    import io
    with zipfile.ZipFile(io.BytesIO(data)) as package:
        root = ET.fromstring(package.read('AppxManifest.xml'))
    manifest = root.find('{http://schemas.microsoft.com/appx/manifest/foundation/windows10}Identity').attrib
    expected_publisher = 'CN=C4997401-2CEE-44B6-9803-4775768C89A5'
    if (manifest.get('Name'), manifest.get('Version'), manifest.get('ProcessorArchitecture'), manifest.get('Publisher')) != (identity, '1.7.17.0', 'x64', expected_publisher):
        raise SystemExit('Staged MSIX manifest mismatch')
    return {'headStatus': head_status, 'getStatus': get_status, 'contentLength': length,
            'contentMD5': md5, 'computedMD5': actual_md5, 'contentMD5Matched': md5 == actual_md5 if md5 else None,
            'zipSHA256': zip_sha.hexdigest(),
            'packageCount': 1, 'fileName': name, 'packageBytes': size, 'sha256': actual,
            'manifest': manifest, 'verified': True, 'reviewSubmitted': False}
