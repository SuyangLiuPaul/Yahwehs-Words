#!/usr/bin/env python3
"""Verify Flutter startup manifests, including SPA responses with HTTP 200."""
import base64
import json
import sys
import urllib.request


def verify_payloads(encoded, binary, fonts):
    value = json.loads(encoded)
    if not isinstance(value, str):
        raise ValueError('AssetManifest JSON must contain the binary wrapper')
    decoded = base64.b64decode(value, validate=True)
    if not binary or decoded != binary:
        raise ValueError('AssetManifest wrapper and binary differ or are empty')
    entries = json.loads(fonts)
    if not isinstance(entries, list) or not entries:
        raise ValueError('FontManifest must be a non-empty list')
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get('family'), str):
            raise ValueError('FontManifest family is malformed')
        variants = entry.get('fonts')
        if not isinstance(variants, list) or not variants:
            raise ValueError('FontManifest variants are malformed')
        if any(not isinstance(v, dict) or not isinstance(v.get('asset'), str)
               for v in variants):
            raise ValueError('FontManifest asset is malformed')
    return len(binary), len(entries)


def verify_site(base):
    payloads = []
    for name in ['AssetManifest.bin.json', 'AssetManifest.bin', 'FontManifest.json']:
        request = urllib.request.Request(base.rstrip('/') + '/assets/' + name,
                                         headers={'Cache-Control': 'no-cache'})
        with urllib.request.urlopen(request, timeout=25) as response:
            if 'text/html' in response.headers.get('Content-Type', ''):
                raise ValueError(name + ' returned the SPA HTML fallback')
            payloads.append(response.read(16 * 1024 * 1024 + 1))
            if len(payloads[-1]) > 16 * 1024 * 1024:
                raise ValueError(name + ' exceeds the verification size limit')
    return verify_payloads(*payloads)


if __name__ == '__main__':
    try:
        size, families = verify_site(sys.argv[1])
        print(f'  ✓ Flutter startup manifests match: {size} bytes, {families} font families')
    except Exception as error:
        print('  ✗ Flutter startup manifest verification: ' + str(error), file=sys.stderr)
        sys.exit(1)
