#!/usr/bin/env python3
"""validate raw samples and summarize accepted exact-pixel runs."""
import json,statistics,math
from pathlib import Path
p=Path(__file__).resolve().parents[1]
summary=[]
for resolution in ['1280x720','2560x1440']:
 d=json.loads((p/('editor-'+resolution)/'performance.json').read_text())
 assert len(d['rows'])==16
 for v in ['concept','breakwater','box-rows','breach']:
  for look in ['old','new']:
   rows=[r for r in d['rows'] if r['view']==v and r['look']==look]
   assert len(rows)==2 and all(len(r['samples'])==120 for r in rows)
   samples=[s for r in rows for s in r['samples']]
   row={'resolution':resolution,'view':v,'look':look,'samples':len(samples),'round_medians':[]}
   for metric in ['gpu_ms','frame_ms','cpu_ms']:
    values=sorted(s[metric] for s in samples)
    assert all(math.isfinite(x) and x>0 for x in values)
    row[metric]={'mean':statistics.mean(values),'median':statistics.median(values),'p95':values[math.ceil(.95*len(values))-1],'min':min(values),'max':max(values)}
   row['round_medians']=[{k:statistics.median(s[k] for s in r['samples']) for k in ['gpu_ms','frame_ms']} for r in rows]
   summary.append(row)
(p/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('| resolution | view | look | GPU median / p95 ms | frame median / p95 ms |')
print('|---|---|---|---:|---:|')
for r in summary:
 print('| {resolution} | {view} | {look} | {gm:.4f} / {gp:.4f} | {fm:.4f} / {fp:.4f} |'.format(**r,gm=r['gpu_ms']['median'],gp=r['gpu_ms']['p95'],fm=r['frame_ms']['median'],fp=r['frame_ms']['p95']))
