#!/usr/bin/env python3
"""read-only manifest comparison against the laptop experiment git objects."""
import hashlib,json,subprocess as sp,zipfile
from pathlib import Path
outer=Path('/home/thatmike1/foldrunner-build-2026-11-05/look')
repo=outer/'wt'
with zipfile.ZipFile(outer/'delivery/SpillwayLookC-linux-x86_64.zip') as z:
 m=json.loads(z.read('SpillwayLookC-linux-x86_64/BUILD.json'))
p=sp.Popen(['git','cat-file','--batch'],cwd=repo,stdin=sp.PIPE,stdout=sp.PIPE)
rows=[]
for path,expected in m['source_files'].items():
 p.stdin.write((m['source_commit']+':projects/foldrunner/'+path+'\n').encode());p.stdin.flush()
 header=p.stdout.readline().decode().strip()
 if header.endswith(' missing'):
  rows.append({'path':path,'expected':expected,'missing':True});continue
 size=int(header.split()[-1]);data=p.stdout.read(size);p.stdout.read(1)
 actual=hashlib.sha256(data).hexdigest()
 rows.append({'path':path,'expected':expected,'actual':actual,'match':actual==expected})
p.stdin.close();p.wait()
print(json.dumps({'source_commit':m['source_commit'],'live_head':sp.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'rows':rows,'mismatches':[r for r in rows if not r.get('match')]},indent=2))
