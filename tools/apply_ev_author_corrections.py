#!/usr/bin/env python3
"""Apply the EV author's approved G2304 correction; guard H7307 against regression.

The owner supplied the author's approval on 2026-10-09. The original EV
package is retained separately; this is an authorized application correction,
not a claim that an updated upstream package has been released. No Bible text,
Nave's material, or unrelated lexicon entry is changed. Default: dry run.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OLD = "2) spoken of the only and true God, trinity"
NEW = "2) spoken of the only and true God"
EXPECTED_ORIGINAL = 'theios \n\n from 2316; TDNT - 3:122,322; adj\n\n AV - divine 2\n\n1) a general name of deities or divinities as used by the Greeks\n\n2) spoken of the only and true God, trinity\n\n2a) of Christ\n\n2b) Holy Spirit\n\n2c) the Father'
NOTE = ("[Eagle's View version] With the author's permission, the word "
        "“trinity” was removed from item 2 of the EV package's outline.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    # These are the Hebrew assets actually shipped by both apps. Their H7307
    # entries already lack the rejected EV clause: never import it to fix it.
    for relative in ('assets/strongs/hebrew.json', 'assets/strongs/bdb_zh.json'):
        entry = json.loads((ROOT / relative).read_text())['H7307']
        text = json.dumps(entry, ensure_ascii=False).casefold()
        if any(term in text for term in ('三一神', '三位一體', '三位一体', '同荣', '同榮', '同尊', 'trinity', 'triune', 'coequal', 'coeternal')):
            raise SystemExit(f'Unexpected H7307 wording in {relative}; inspect before editing.')
        print(f'H7307: rejected EV clause absent in {relative}; retained unchanged')
    path = ROOT / 'assets/thayer.json'
    raw = path.read_text()
    obj = json.loads(raw)
    current = obj['entries']['G2304']
    updated = EXPECTED_ORIGINAL.replace(OLD, NEW) + '\n\n' + NOTE
    if current == EXPECTED_ORIGINAL:
        pass
    elif current == updated:
        print('G2304: already corrected')
        return
    else:
        raise SystemExit('Unexpected G2304 text; refusing to guess a replacement.')
    # Replace precisely one encoded entry value; retain formatting and all
    # other entries, including different app-specific attribution metadata.
    old_json = json.dumps(current, ensure_ascii=False)
    new_json = json.dumps(updated, ensure_ascii=False)
    if raw.count(old_json) != 1:
        raise SystemExit('Ambiguous serialized G2304 entry; refusing to write.')
    output = raw.replace(old_json, new_json)
    after = json.loads(output)
    after['entries']['G2304'] = current
    if after != obj:
        raise SystemExit('Unexpected changes outside G2304.')
    print('G2304: remove “, trinity” from item 2; preserve subitems and add provenance note')
    if args.write:
        path.write_text(output)
        print('Wrote assets/thayer.json')
    else:
        print('Dry run; pass --write to apply')


if __name__ == '__main__':
    main()
