from pathlib import Path
import html
import json
import subprocess

OUT = Path('/home/thatmike1/foldrunner-build-2026-11-05/look')
MAPS = [
    ('breakwater', 'Breakwater', 'Container port · pale decks, teal steel and late light'),
    ('whiteout-relay', 'Whiteout Relay', 'Snowy ridge · warm route tops against cool snow'),
    ('sunken-court', 'Sunken Court', 'Sunlit ruins · cream stone tops, quiet green-grey faces'),
    ('rainline', 'Rainline', 'Rainy rooftops · pale roofs, slate sides and painted storm sky'),
    ('night-shift', 'Night Shift', 'Night depot · pale platforms, dark trains and indigo clouds'),
    ('practice', 'Penstock Yard', 'Practice yard · cream blocks and orange jump lips'),
    ('overflow', 'Overflow', 'Dam descent · warm tops, sea-glass water and painted afternoon'),
    ('experiment', 'Movement Lab', 'Training hall · pale lanes, dark housings and quiet lamps'),
]
style = '''
<style>
:root{font-family:var(--font-sans,system-ui);color:var(--foreground,#263c45)}
body{margin:0}h2{font-size:20px;margin:20px 0 5px;font-weight:600}
p{font-size:13px;line-height:1.5;color:var(--muted-foreground,#62757d);margin:7px 0 14px}
nav{display:flex;flex-wrap:wrap;gap:5px 16px;margin:0 0 14px}
button,select{font:inherit;font-size:13px;color:var(--foreground,#263c45);background:transparent;border:0;border-bottom:2px solid transparent;padding:8px 0;cursor:pointer}
button[aria-pressed=true]{border-color:var(--chart-1,#315d84);font-weight:600}
select{border:1px solid var(--border,#adb9bf);padding:5px 8px;border-radius:var(--radius,5px);background:var(--background,#fff)}
.toolbar{display:flex;gap:12px;align-items:center;font-size:13px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}
figure{margin:0;min-width:0}img{display:block;width:100%;height:auto}figcaption{font-size:12px;color:var(--muted-foreground,#62757d);margin:8px 0 6px}
a{color:var(--primary,#315d84)}[hidden]{display:none!important}
.foot{border-top:1px solid var(--border,#ccd6da);padding-top:12px;margin-top:20px}
@media(max-width:520px){.pair{grid-template-columns:1fr}nav{gap:0 13px}}
</style>'''
parts = ['<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">', style, '</head><body>']
parts.append('<nav aria-label="Maps">')
for i, (key, name, _) in enumerate(MAPS):
    parts.append(f'<button type="button" data-map-button="{key}" aria-pressed="{str(i==0).lower()}" onclick="selectMap(\'{key}\')">{html.escape(name)}</button>')
parts.append('</nav><div class="toolbar"><label for="pose">Camera</label><select id="pose" onchange="selectPose(this.value)"><option value="route">Route</option><option value="spawn">Entry</option><option value="concept" id="concept-option">Concept angle</option></select></div>')
for i, (key, name, description) in enumerate(MAPS):
    root = OUT/'evidence/r17-views-final'/key
    proof = json.loads((root/'views.json').read_text())
    parts.append(f'<section data-map="{key}"'+(' hidden' if i else '')+f'><h2>{html.escape(name)}</h2><p>{html.escape(description)}</p>')
    views = sorted({x['view'] for x in proof['views']})
    for view in views:
        parts.append(f'<div class="pair" data-pose="{view}"'+(' hidden' if view!='route' else '')+'>')
        for mode, caption in [('old','Original R16'), ('new','R17 paint + ink')]:
            path = root/f'{view}-{mode}.png'
            assert path.is_file()
            thumb = root / (path.stem + "-preview.jpg")
            subprocess.run(["magick", str(path), "-resize", "640x360", "-quality", "84", str(thumb)], check=True)
            parts.append(f'<figure><figcaption>{caption}</figcaption><img src="{thumb}" alt="{html.escape(name)} {view}: {caption}"></figure>')
        parts.append('</div>')
    movie = OUT/f'r17-{key}.mp4'
    if movie.is_file():
        parts.append(f'<p><a href="{movie}">Native run excerpt</a></p>')
    parts.append('</section>')
parts.append('<p class="foot">Identical camera poses and FOV. Gameplay paused; weather effects can animate between frames. Native 1280 × 720 renders on the laptop AMD GPU, runtime source 7c82e0877. This page is the visual evidence pass; full moving parity, desktop GPU cost and portable acceptance are still being verified.</p>')
parts.append('''<script>
let selectedMap='breakwater',selectedPose='route';
function refresh(){
 document.querySelectorAll('[data-map]').forEach(e=>e.hidden=e.dataset.map!==selectedMap);
 document.querySelectorAll('[data-map-button]').forEach(e=>e.setAttribute('aria-pressed',String(e.dataset.mapButton===selectedMap)));
 document.querySelectorAll('[data-pose]').forEach(e=>e.hidden=e.dataset.pose!==selectedPose);
 document.getElementById('concept-option').hidden=selectedMap!=='breakwater';
 document.getElementById('pose').value=selectedPose;
}
function selectMap(id){selectedMap=id;if(id!=='breakwater'&&selectedPose==='concept')selectedPose='route';refresh();}
function selectPose(id){selectedPose=id;refresh();}
</script></body></html>''')
page = ''.join(parts)
(OUT/'comparison-r17.html').write_text(page)
print('wrote',OUT/'comparison-r17.html',len(page),'bytes')
