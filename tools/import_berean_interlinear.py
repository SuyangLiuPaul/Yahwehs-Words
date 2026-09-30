#!/usr/bin/env python3
"""Import the official BIB NT DOCX, preserving document word order and alignment.

Usage: python3 tools/import_berean_interlinear.py /path/to/bib.docx
Download: https://interlinearbible.com/bib.docx (official downloads page).
The BSB translation tables contain BSB glosses, not BIB glosses, and are
intentionally not used here. No external hyperlink is followed or executed.
"""
import argparse
import hashlib
import json
import re
import zipfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

BOOKS = ['Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
         '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
         'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
         '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
         '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation']
W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
R = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'

def text(node):
    return ''.join((' ' if t.tag == W+'br' else t.text or '')
                   for t in node.iter() if t.tag in {W+'t', W+'br'}).replace('\u00a0', ' ')

def dump(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('docx', type=Path)
    ap.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = ap.parse_args()
    payload = args.docx.read_bytes()
    with zipfile.ZipFile(args.docx) as archive:
        document = ET.fromstring(archive.read('word/document.xml'))
        relations = ET.fromstring(archive.read('word/_rels/document.xml.rels'))
    links = {r.get('Id'): r.get('Target','') for r in relations}
    conflicts = []
    verses = defaultdict(list)
    notes = defaultdict(list)
    book = None
    chapter = None
    current = None
    for p in document.findall(W+'body/'+W+'p'):
        whole = text(p).strip()
        heading = re.fullmatch(r'(.+?) (\d+)', whole)
        if heading and heading[1] in BOOKS:
            book, chapter, current = heading[1], int(heading[2]), None
            continue
        if book is None or chapter is None:
            continue
        style = p.find(W+'pPr/'+W+'pStyle')
        style = style.get(W+'val','') if style is not None else ''
        if style == 'foot':
            notes[(book,chapter)].append(whole)
            continue
        if style == 'hdg' or not whole:
            continue
        for node in p:
            if node.tag == W+'pPr':
                continue
            value = text(node)
            run_style = node.find(W+'rPr/'+W+'rStyle')
            if (run_style is not None and run_style.get(W+'val') == 'reftext1'
                    and value.strip().isdigit()):
                current = (book,chapter,int(value.strip()))
                if current in verses:
                    raise ValueError(f'Duplicate verse anchor: {current}')
                verses[current] = []
                continue
            if current is None or not value:
                continue
            if run_style is not None and run_style.get(W+'val') == 'reftext1':
                continue
            run = {'w': value, 's': '', 'i': [], 'g': []}
            if node.tag == W+'hyperlink':
                target = links.get(node.get(R+'id'), '')
                number = re.fullmatch(r'https?://biblehub.com/greek/(\d+)\.htm', target)
                tooltip = node.get(W+'tooltip','')
                parsed = re.match(r'(.+?) (\d+): (.+?) -- ', tooltip)
                if number:
                    run['s'] = 'G'+number[1]
                if parsed:
                    if number and parsed[2] != number[1]:
                        conflicts.append({'verse':list(current), 'link':number[1], 'tooltip':parsed[2]})
                        run['s'] = ''  # Source disagrees; do not promise a word identity.
                    run['g'] = [parsed[1]]
                    run['t'] = parsed[3]
                    # The linked run is an English gloss. Its original
                    # form is the preceding Greek source text, not the
                    # English word paired with a Greek transliteration.
                    preceding = []
                    for prior in reversed(verses[current]):
                        if prior.get('t') is not None:
                            break
                        preceding.insert(0, prior['w'])
                    forms = re.findall(r'[\u0370-\u03ff\u1f00-\u1fff][\u0370-\u03ff\u1f00-\u1fff\u0300-\u036f]*', ''.join(preceding))
                    if forms:
                        run['o'] = ' '.join(forms)
            verses[current].append(run)
        # A continuation paragraph is part of the same verse, separated
        # visibly so two Greek words never fuse at a paragraph boundary.
        if current and verses[current]:
            verses[current].append({'w':' ', 's':'', 'i':[], 'g':[]})
    if len({b for b,c,v in verses}) != 27 or len({(b,c) for b,c,v in verses}) != 260:
        raise ValueError('Incomplete BIB NT document')
    plain = []
    tagged = defaultdict(dict)
    for (b,c,v), runs in verses.items():
        body = ''.join(r['w'] for r in runs).strip()
        # Whitespace normalization is typesetting-only. Word wording,
        # variant delimiters, and punctuation are retained verbatim.
        body = re.sub(r'\s+', ' ', body)
        item = {'book':b,'chapter':str(c),'verse':str(v),'text':body,
                'id':f'{BOOKS.index(b)+40:03}{c:03}{v:03}'}
        if v == min(x[2] for x in verses if x[0] == b and x[1] == c) and notes.get((b,c)):
            chapter_note = '<note:BIB source chapter notes — '+ ' '.join(notes[(b,c)]).replace('>', '›')+'>'
            item['text'] += ' ' + chapter_note
            runs.append({'w':chapter_note, 's':'', 'i':[], 'g':[]})
        plain.append(item)
        tagged[b][f'{c}:{v}'] = runs
    # Preserve chapter footnotes separately; do not invent a verse anchor
    # for a paragraph containing several source letter/verse references.
    dump(args.root/'assets/bib.json', plain)
    for b, contents in tagged.items():
        dump(args.root/'assets/tagged/bib'/f'{b.replace(" ", "_")}.json', contents)
    dump(args.root/'assets/bib_chapter_notes.json',
         {f'{b} {c}':' '.join(n) for (b,c),n in notes.items()})
    manifest = {'source':'https://interlinearbible.com/bib.docx',
                'source_sha256':hashlib.sha256(payload).hexdigest(),
                'license':'Public domain effective 2023-04-30',
                'license_url':'https://berean.bible/licensing.htm',
                'coverage':'New Testament only', 'books':27, 'chapters':260,
                'verses':len(plain), 'word_tags':sum(bool(r['s']) for runs in verses.values() for r in runs),
                'chapter_note_groups':len(notes), 'source_strong_conflicts':conflicts,
                'transformations':['NBSP and paragraph whitespace normalized',
                                   'verse anchors supplied by source run style',
                                   'hyperlink Strong numbers and tooltip morphology/transliteration retained',
                                   'chapter footnotes retained separately and labeled on the first present verse; no lexical definitions imported']}
    dump(args.root/'docs/berean-interlinear-import.json', manifest)
    print(json.dumps(manifest, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
