#!/usr/bin/env python3
"""assemble the local all-map comparison from preserved native evidence."""
from pathlib import Path
import html
import json
import subprocess

ROOT = Path('/home/thatmike1/foldrunner-build-2026-11-05/look')
MAPS = [
    ('breakwater','Breakwater','Container port · cream decks, weathered teal steel and warm light'),
    ('whiteout-relay','Whiteout Relay','Snowy ridge · warm route tops against cool snow'),
    ('sunken-court','Sunken Court','Sunlit ruins · cream stone tops and warmer muted stone faces'),
    ('rainline','Rainline','Rainy rooftops · pale roofs, slate sides and a painted storm sky'),
    ('night-shift','Night Shift','Night depot · pale platforms, dark trains and indigo clouds'),
    ('practice','Penstock Yard','Practice yard · cream blocks and orange gap lips'),
    ('overflow','Overflow','Dam descent · warm tops, sea-glass water and painted afternoon'),
    ('experiment','Movement Lab','Training hall · pale lanes, separate room values and functional lamps'),
]

final_gpu = ROOT/'evidence/r17-desktop-gpu-final'
gpu_root = final_gpu if (final_gpu/'PARENT-AUDIT.json').exists() else ROOT/'evidence/r17-desktop-gpu'
gpu = json.loads((gpu_root/'analysis.json').read_text())['comparisons'] if (gpu_root/'analysis.json').exists() else []
delivery = ROOT.parent/'delivery/spillway-r17'
build = json.loads((delivery/'BUILD.json').read_text()) if (delivery/'BUILD.json').exists() else {}
final_audit = json.loads((final_gpu/'PARENT-AUDIT.json').read_text()) if (final_gpu/'PARENT-AUDIT.json').exists() else {}
final = gpu_root == final_gpu and final_audit.get('ok',False) and final_audit.get('source_commit') == build.get('source_commit') and final_audit.get('pack_sha256') == build.get('pack_sha256')
if not final and gpu_root == final_gpu:
    gpu_root = ROOT/'evidence/r17-desktop-gpu'
    gpu = json.loads((gpu_root/'analysis.json').read_text())['comparisons']
gpu_label = 'Final release · RTX 2070 SUPER · NVIDIA 595.99.02' if final else 'Earlier candidate 5e1004fd · final release timing pending'
clips = {x['map']:x for x in json.loads((ROOT/'evidence/r17-movies/summary.json').read_text())['maps']}
data = json.dumps({'gpu':gpu,'gpuLabel':gpu_label},separators=(',',':')).replace('</','<\\/')
css = '''<style>
:root{font-family:var(--font-sans,system-ui);color:var(--foreground,#253b43)}body{margin:0}
h2{font-size:20px;font-weight:600;margin:20px 0 5px}h3{font-size:15px;font-weight:600;margin:18px 0 6px}
p,figcaption,.toolbar,.metric{font-size:13px;line-height:1.5}p{color:var(--muted-foreground,#60737b);margin:6px 0 12px}
nav{display:flex;flex-wrap:wrap;gap:3px 15px;margin-bottom:12px}
button,select{font:inherit;font-size:13px;color:var(--foreground,#253b43);cursor:pointer}
button{background:transparent;border:0;border-bottom:2px solid transparent;padding:7px 0}
button[aria-pressed=true]{border-color:var(--primary,#315d84);font-weight:600}
select{background:var(--background,#fff);border:1px solid var(--border,#acb9bf);border-radius:var(--radius,5px);padding:4px 7px}
.toolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}
figure{margin:0;min-width:0}img{display:block;width:100%;height:auto}figcaption{color:var(--muted-foreground,#60737b);margin:7px 0}
a{color:var(--primary,#315d84)}.native{display:flex;gap:12px;flex-wrap:wrap;margin-top:12px;font-size:13px}
.gpu{border-top:1px solid var(--border,#c6d1d6);margin-top:16px;padding-top:1px}.gpu-head{display:flex;justify-content:space-between;gap:12px;align-items:center;flex-wrap:wrap}
svg{display:block;width:100%;height:112px;overflow:visible}.metric{margin:2px 0 8px;color:var(--foreground,#253b43)}
.foot{border-top:1px solid var(--border,#c6d1d6);padding-top:12px;margin-top:18px;font-size:12px}
.links{display:flex;gap:14px;flex-wrap:wrap;font-size:13px;margin-top:12px}[hidden]{display:none!important}
@media(max-width:520px){.pair{grid-template-columns:1fr}nav{gap:1px 13px}}
</style>'''
parts = ['<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',css,'</head><body><nav aria-label="Maps">']
for i,(key,name,_) in enumerate(MAPS):
    parts.append(f'<button type="button" data-map-button="{key}" aria-pressed="{str(i==0).lower()}" onclick="selectMap(\'{key}\')">{html.escape(name)}</button>')
parts.append('</nav><div class="toolbar"><label for="pose">Camera</label><select id="pose" onchange="selectPose(this.value)"><option value="route">Route</option><option value="spawn">Entry</option><option value="concept" id="concept-option">Concept angle</option></select></div>')
for i,(key,name,description) in enumerate(MAPS):
    folder = ROOT/'evidence/r17-views-final'/key
    proof = json.loads((folder/'views.json').read_text())
    parts.append(f'<section data-map="{key}"'+(' hidden' if i else '')+f'><h2>{html.escape(name)}</h2><p>{html.escape(description)}</p>')
    for view in sorted({x['view'] for x in proof['views']}):
        parts.append(f'<div class="pair" data-pose="{view}"'+(' hidden' if view!='route' else '')+'>')
        for mode,caption in [('old','Original R16 presentation'),('new','R17 paint + ink')]:
            original = folder/f'{view}-{mode}.png'
            thumb = folder/f'{view}-{mode}-preview.jpg'
            if not thumb.exists() or thumb.stat().st_mtime < original.stat().st_mtime:
                subprocess.run(['magick',str(original),'-resize','640x360','-quality','84',str(thumb)],check=True)
            parts.append(f'<figure><figcaption>{caption}</figcaption><img src="{thumb}" alt="{html.escape(name)} {view}, {caption}"></figure>')
        parts.append('</div>')
    clip = clips[key]
    preset = {'server128':'F2','server128_aa1000':'F5','quake3_inspired128':'F4 Quake III'}[clip['preset']]
    parts.append(f'<div class="native"><a href="{clip["movie"]}">Native run excerpt</a><span>Peak {clip["peak_u_s"]:.0f} u/s · {preset} · silent, actual player camera</span></div>')
    parts.append('</section>')
parts.append('''<div class="gpu"><div class="gpu-head"><h3>Fixed-view GPU time</h3><div class="toolbar"><label for="resolution">Pixels</label><select id="resolution" onchange="refreshGpu()"><option>2560x1440</option><option>1280x720</option></select></div></div><p id="gpu-source"></p><svg id="gpu-chart" viewBox="0 0 640 112" role="img" aria-labelledby="gpu-chart-title"><title id="gpu-chart-title">Original and R17 GPU milliseconds</title></svg><div id="gpu-values" class="metric" aria-live="polite"></div><p>Median bars; ticks show p95. Lower is less GPU time. Paused cameras, vsync off, two alternating orders, 40 warmup + 120 measured frames per look/view/order. These measurements do not establish moving frame pacing or physical input latency.</p></div>''')
parts.append('<div class="links">'+''.join(f'<a href="{ROOT/path}">{label}</a>' for path,label in [('RESULTS-R17.md','Player notes and limits'),('REVIEW-R17.md','Visual review'),('REVIEW-R17-RESPONSE.md','Review fixes'),(str(gpu_root.relative_to(ROOT)/'report.md'),'GPU report')])+ '</div>')
parts.append('<p class="foot">17 native matched pairs, identical camera poses and FOV. PNG evidence: evidence/r17-views-final/. JPEGs here are display previews. Views and native clips use readability-fixed runtime b406e2d2a. Native PNGs are 1296×736; clips are 1280×720 at 60 fps. The review describes the earlier source, with fixes recorded in the review addendum. Weather can animate between paused captures. L compares the two presentations in the game.</p>')
parts.append('<script>const evidence='+data+';'+'''
let selectedMap='breakwater',selectedPose='route';
function refresh(){
 document.querySelectorAll('[data-map]').forEach(e=>e.hidden=e.dataset.map!==selectedMap);
 document.querySelectorAll('[data-map-button]').forEach(e=>e.setAttribute('aria-pressed',String(e.dataset.mapButton===selectedMap)));
 document.querySelectorAll('[data-pose]').forEach(e=>e.hidden=e.dataset.pose!==selectedPose);
 document.getElementById('concept-option').hidden=selectedMap!=='breakwater';
 document.getElementById('pose').value=selectedPose;refreshGpu();
}
function selectMap(id){selectedMap=id;if(id!=='breakwater'&&selectedPose==='concept')selectedPose='route';refresh();}
function selectPose(id){selectedPose=id;refresh();}
function refreshGpu(){
 const resolution=document.getElementById('resolution').value;
 const c=evidence.gpu.find(x=>x.map===selectedMap&&x.view===selectedPose&&x.resolution===resolution);
 document.getElementById('gpu-source').textContent=evidence.gpuLabel;
 const svg=document.getElementById('gpu-chart'),values=document.getElementById('gpu-values');
 svg.replaceChildren();if(!c){values.textContent='Awaiting matched final-release measurements.';return;}
 const ns='http://www.w3.org/2000/svg';
 function add(tag,attrs,text){const e=document.createElementNS(ns,tag);for(const[k,v]of Object.entries(attrs))e.setAttribute(k,String(v));if(text!==undefined)e.textContent=text;svg.append(e);return e;}
 add('title',{id:'gpu-chart-title'},'GPU milliseconds: original '+c.gpu_ms_median_old.toFixed(3)+', R17 '+c.gpu_ms_median_new.toFixed(3));
 const max=Math.ceil(Math.max(...evidence.gpu.map(x=>Math.max(x.gpu_ms_p95_old,x.gpu_ms_p95_new)))*2)/2;
 const frameWidth=Math.max(300,Math.round(svg.getBoundingClientRect().width));
 svg.setAttribute('viewBox','0 0 '+frameWidth+' 112');
 const origin=76,width=Math.max(100,frameWidth-origin-86),scale=width/max;
 for(let t=0;t<=max+.001;t+=.5){const x=origin+t*scale;add('line',{x1:x,x2:x,y1:9,y2:82,stroke:'var(--border,#cad4d9)','stroke-width':.6});if(Number.isInteger(t)||t===max)add('text',{x,y:103,fill:'var(--muted-foreground,#60737b)','font-size':11,'text-anchor':'middle'},t.toFixed(t%1?1:0));}
 for(const[mode,label,y,color]of [['old','Original',18,'var(--muted-foreground,#6a7d85)'],['new','R17',55,'var(--primary,#315d84)']]){
  const median=c['gpu_ms_median_'+mode],p95=c['gpu_ms_p95_'+mode];
  add('text',{x:63,y:y+15,fill:'var(--foreground,#253b43)','font-size':12,'text-anchor':'end'},label);
  add('rect',{x:origin,y,width:Math.max(1,median*scale),height:21,rx:2,fill:color});
  add('line',{x1:origin+median*scale,x2:origin+p95*scale,y1:y+10.5,y2:y+10.5,stroke:color,'stroke-width':1.5});
  add('line',{x1:origin+p95*scale,x2:origin+p95*scale,y1:y+4,y2:y+17,stroke:color,'stroke-width':1.5});
  add('text',{x:origin+width+12,y:y+15,fill:'var(--foreground,#253b43)','font-size':12},median.toFixed(3)+' ms');
 }
 const delta=c.gpu_ms_median_delta,percent=(c.gpu_ms_median_ratio-1)*100;
 values.textContent='Median '+c.gpu_ms_median_old.toFixed(3)+' → '+c.gpu_ms_median_new.toFixed(3)+' ms. '+(delta>=0?'+':'')+delta.toFixed(3)+' ms ('+(percent>=0?'+':'')+percent.toFixed(2)+'%).';
}
window.addEventListener('resize',refreshGpu);
refresh();
</script></body></html>''')
page=''.join(parts)
(ROOT/'comparison-r17.html').write_text(page)
print('wrote comparison-r17.html',len(page),'bytes;',gpu_label)
