#!/usr/bin/env python3
"""Read-only review candidates, never a theological or Scripture rewrite.

Explicit Trinity commentary is distinguished from interpretive Christology
and from quotation/negation. Source identities and surrounding text remain
available for a human review; a keyword hit alone is not a doctrinal verdict.
"""
import argparse
import csv
import hashlib
import io
import json
import re
import subprocess
from pathlib import Path

RULES = [
    ('explicit-trinity', r'\btrinit(?:y|arian|arianism)\b|三位一[体體]|三一神|三一論|三一论|三位格|third\s+(?:person|member).*?(?:Godhead|Trinity)'),
    ('personhood-or-equality', r'co[- ]?equal|co[- ]?eternal|consubstantial|same\s+(?:divine\s+)?(?:essence|substance)|三個位格|三个位格|同質|同质|同榮.{0,8}同尊|同荣.{0,8}同尊|(?:second|third)\s+person\s+(?:of|in)|(?:聖靈|圣灵).{0,35}(?:位格|人格)'),
    ('christology-review', r'(?:Christ|Jesus|the Son).{0,90}(?:God himself|very God|true God|Godhead|divine nature|divine essence)|(?:God himself|very God|true God|Godhead).{0,90}(?:Christ|Jesus|the Son)|(?:基督|耶穌|耶稣).{0,40}(?:神性|神格|就是神|即是神|永恆|永恒|真神)|道.{0,20}(?:神格|神性|就是神)'),
]

def plain(text, encoding='cp1252'):
    # EV's Chinese definitions are RTF hex bytes in GBK, not UTF-8 text.
    # Decode a whole byte run so a two-byte Han character stays together.
    text = re.sub(r"(?:\\'[0-9a-fA-F]{2})+", lambda m: bytes.fromhex(m.group().replace("\\'", '')).decode(encoding, errors='replace'), text)
    text = re.sub(r'\\u(-?\d+)\??', lambda m: chr(int(m[1]) % 65536), text)
    text = text.replace('\\par', '\n')
    text = re.sub(r'\\[a-z]+-?\d*\s?', '', text)
    return re.sub(r'[ \t]+', ' ', text).strip()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    rules = [(name, re.compile(pattern, re.I | re.S)) for name, pattern in RULES]
    files, hits, errors = [], [], []
    for file in sorted(args.source.iterdir()):
        if file.suffix.lower() not in {'.dct', '.mdb', '.cdb', '.not', '.4g', '.ot'}:
            continue
        inventory = {'file': file.name, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'tables': []}
        files.append(inventory)
        tables = subprocess.run(['mdb-tables', '-1', str(file)], capture_output=True, text=True)
        if tables.returncode:
            errors.append({'file':file.name, 'operation':'tables', 'error':tables.stderr.strip()}); continue
        for table in tables.stdout.splitlines():
            export = subprocess.run(['mdb-export', str(file), table], capture_output=True, text=True)
            if export.returncode:
                errors.append({'file':file.name,'table':table,'error':export.stderr.strip()}); continue
            count = 0
            for row in csv.DictReader(io.StringIO(export.stdout)):
                count += 1
                identity = {k:v for k,v in row.items() if k.lower() in {'id','topic','book','chapter','verse','reference','title','strongs'}}
                for field, raw in row.items():
                    if not raw: continue
                    text = plain(raw, 'gbk' if file.name == 'Strong SCh.dct' else 'cp1252')
                    found = [(name, regex.search(text)) for name,regex in rules]
                    found = [(name,match) for name,match in found if match]
                    if not found: continue
                    snippets = []
                    for name,match in found:
                        snippets.append({'rule':name,'match':match.group(), 'context':text[max(0,match.start()-180):match.end()+230]})
                    hits.append({'file':file.name,'table':table,'row':count,'identity':identity,'field':field,
                                 'rules':[name for name,_ in found], 'snippets':snippets,'text':text})
            inventory['tables'].append({'table':table,'rows':count})
    report = {'scope':'Readable EV dictionary/study database fields, excluding .bbl Bible modules and executables. Candidates require human review; negation, quotations and lexical usage can match. Sources unchanged.',
              'rules':[{'name':n,'pattern':p} for n,p in RULES], 'files':files,'hits':hits,'errors':errors}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'files':len(files),'tables':sum(len(x['tables']) for x in files),
                      'rows':sum(t['rows'] for x in files for t in x['tables']), 'candidate_fields':len(hits),'errors':len(errors)}))

if __name__ == '__main__': main()
