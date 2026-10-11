"""Read-only audit of Git-tracked, runtime-supported tagged editions."""
import hashlib,json,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
service=(root/'lib/services/tagged_text_service.dart').read_text()
block=service.split('taggedVersions = {',1)[1].split('};',1)[0]
versions=re.findall(r"^\s*'([^']+)'",block,re.M)
lex=set()
for name in ['greek','hebrew']:
 lex.update(json.loads((root/f'assets/strongs/{name}.json').read_text()))
tracked=subprocess.check_output(['git','ls-files','assets/tagged'],cwd=root,text=True).splitlines()
report={'scope':'Git-tracked JSON in runtime taggedVersions; static candidates, not per-token device verification','versions':{},'files_sha256':{},'schema_anomalies':[], 'hebrews_7_27':{}}
for v in versions:
 c=dict(files=0,verses=0,tokens=0,multi_distinct_lexical=0,multi_dictionary_backed=0,implied_only=0,additional_s2=0,missing_dictionary_numbers=0,grammar_range_in_lexical_fields=0,hebrews_verses=0)
 for name in tracked:
  p=Path(name)
  if p.suffix!='.json' or p.parts[2]!=v:continue
  data=(root/p).read_bytes();report['files_sha256'][name]=hashlib.sha256(data).hexdigest()
  book=json.loads(data);c['files']+=1;c['verses']+=len(book)
  if p.stem.lower()=='hebrews': c['hebrews_verses']+=len(book);report['hebrews_7_27'][v]=book.get('7:27')
  for ref,runs in book.items():
   for r in runs:
    c['tokens']+=1
    if not isinstance(r.get('s',''),str) or any(not isinstance(r.get(k,[]),list) for k in ['i','s2','g']):
     report['schema_anomalies'].append([name,ref,r]);continue
    nums=[r.get('s',''),*r.get('s2',[]),*r.get('i',[])]
    valid={n for n in nums if isinstance(n,str) and re.fullmatch('[HG][1-9][0-9]*',n)}
    c['multi_distinct_lexical']+=len(valid)>1
    c['multi_dictionary_backed']+=len(valid&lex)>1
    c['implied_only']+=not r.get('s') and bool(r.get('i'))
    c['additional_s2']+=bool(r.get('s2'))
    c['missing_dictionary_numbers']+=len(valid-lex)
    c['grammar_range_in_lexical_fields']+=sum(int(n[1:])>(8674 if n[0]=='H' else 5624) for n in valid-lex)
 report['versions'][v]=c
report['totals']={k:sum(c[k] for c in report['versions'].values()) for k in c}
print(json.dumps(report,ensure_ascii=False,indent=2))
