#!/usr/bin/env python3
"""build look/ui-r18/index.html: before/after of every r18 screen at three resolutions plus
mid-run frames. images are local only (look/ui-r18/.gitignore); originals stay in the shots dir.

python3 tools/r18-ui-gallery.py --shots ~/.cache/spillway-r18/shots [--release DIR]
"""
import argparse
import html
import json
from pathlib import Path
import shutil

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'look/ui-r18'
RES = ['3440x1440', '2560x1440', '1920x1080']
SCREENS = [
    ('opening', 'Start screen', 'A title card over the live spawn replaces the wall of instructions; it lifts on the first key.'),
    ('hints', 'Opening hints', 'Teaching text becomes two cream tickets under the map name and fades once the run is under way.'),
    ('pause', 'Esc menu', 'A cream sheet with ink type; the current map and preset are ink tiles with an orange edge.'),
    ('pause-lower', 'Esc menu, lower half', 'Presets, look and sound settings and a key list, same sheet.'),
    ('toast', 'Preset switch toast', 'Toasts are a single ticket at the top centre, away from the route.'),
    ('practice', 'Practice', 'The practice tag sits top right under the look label; the route hint stays a ticket.'),
    ('finish', 'Finish', 'Big time, result in sea-glass or coral, style and ghost lines, then the splits table. Staged values.'),
    ('lab', 'Movement Lab start', 'The lab keeps its EXPERIMENTAL tag and move states, hidden only while the title is up.'),
    ('telemetry', 'Telemetry (F9)', 'Identity, key line, strafe panel, build and recording path live behind F9, off by default.'),
]


def jpeg(src, dst, quality=88):
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.open(src).convert('RGB').save(dst, quality=quality, optimize=True)
    return dst.relative_to(OUT).as_posix()


def figure(before, after, label):
    cells = []
    for side, path in (('Before (R17)', before), ('After (R18)', after)):
        if path is None:
            cells.append('<figure class="none"><figcaption>%s</figcaption><p>no equivalent screen</p></figure>' % side)
        else:
            cells.append('<figure><figcaption>%s</figcaption><a href="%s" target="_blank"><img loading="lazy" src="%s" alt="%s %s"></a></figure>'
                         % (side, path, path, html.escape(label), side))
    return '<div class="pair">%s</div>' % ''.join(cells)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--shots', type=Path, required=True)
    p.add_argument('--release', type=Path)
    a = p.parse_args()
    if (OUT / 'img').exists():
        shutil.rmtree(OUT / 'img')
    sections = []
    nav = []
    for key, title, takeaway in SCREENS:
        tabs = []
        for res in RES:
            b = a.shots / 'before' / res / (key + '.png')
            f = a.shots / 'after' / res / (key + '.png')
            if not f.exists():
                continue
            before = jpeg(b, OUT / 'img' / res / ('before-' + key + '.jpg')) if b.exists() and key not in ('hints', 'telemetry') else None
            if key == 'hints' and b.exists():
                before = jpeg(a.shots / 'before' / res / 'opening.png', OUT / 'img' / res / 'before-hints.jpg')
            if key == 'telemetry' and b.exists():
                before = jpeg(b, OUT / 'img' / res / 'before-telemetry.jpg')
            after = jpeg(f, OUT / 'img' / res / ('after-' + key + '.jpg'))
            tabs.append('<div class="res" data-res="%s">%s</div>' % (res, figure(before, after, title)))
        sections.append('<section id="%s"><h2>%s</h2><p class="take">%s</p>%s</section>' % (key, html.escape(title), html.escape(takeaway), ''.join(tabs)))
        nav.append('<a href="#%s">%s</a>' % (key, html.escape(title)))
    runs = []
    for side in ('before', 'after'):
        for capture in sorted((a.shots / (side + '-run')).glob('*/*/capture.json')):
            data = json.loads(capture.read_text())
            for pick in data['picks']:
                src = Path(pick['file'])
                rel = jpeg(src, OUT / 'img/run' / side / src.name)
                runs.append((data['route']['map'], data['preset'], 'x'.join(map(str, data['res'])), pick['tick'], pick['speed_u_s'], side, rel))
    rows = {}
    for m, preset, res, tick, speed, side, rel in runs:
        rows.setdefault((m, res), {}).setdefault(side, []).append((tick, speed, rel, preset))
    run_html = []
    for (m, res), sides in sorted(rows.items()):
        for i in range(max(len(sides.get('before', [])), len(sides.get('after', [])))):
            b = sides.get('before', [])[i] if i < len(sides.get('before', [])) else None
            f = sides.get('after', [])[i] if i < len(sides.get('after', [])) else None
            pick = f or b
            label = '%s · %s · %s · tick %d · %d u/s' % (m, pick[3], res, pick[0], round(pick[1]))
            run_html.append('<h3>%s</h3>%s' % (html.escape(label), figure(b[2] if b else None, f[2] if f else None, label)))
    sections.append('<section id="runs"><h2>Mid-run at speed</h2><p class="take">Real retained-input play on the actual player camera, frames picked at 300+ u/s. The same retained tape in both builds; frames are the nearest readbacks, so ticks can differ by a few.</p>%s</section>' % ''.join(run_html))
    nav.append('<a href="#runs">Mid-run</a>')
    if a.release and a.release.exists():
        shots = sorted(a.release.glob('*/release-*.png'))
        figs = ''.join('<figure><figcaption>%s</figcaption><a href="%s" target="_blank"><img loading="lazy" src="%s"></a></figure>'
                       % (html.escape(s.parent.name + ' ' + s.stem), r, r) for s in shots for r in [jpeg(s, OUT / 'img/release' / (s.parent.name + '-' + s.stem + '.jpg'))])
        sections.append('<section id="release"><h2>Exported release build</h2><p class="take">Screenshots of the exported Linux release, launched from ~/.local/share/foldrunner/spillway-r18/.</p><div class="pair">%s</div></section>' % figs)
        nav.append('<a href="#release">Release build</a>')
    page = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Spillway R18 interface: before and after</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Figtree:wght@400;600;750&display=swap');
:root{--cream:#f3ead7;--ink:#18272e;--edge:#e15a2b;--teal:#2d5f6e}
*{box-sizing:border-box}body{margin:0;background:var(--cream);color:var(--ink);font:16px/1.5 Figtree,system-ui,sans-serif}
header{position:sticky;top:0;z-index:2;background:var(--ink);color:var(--cream);padding:14px 32px;display:flex;gap:28px;align-items:center;flex-wrap:wrap}
header h1{margin:0;font-size:19px;font-weight:750}header nav{display:flex;gap:14px;flex-wrap:wrap;font-size:14px}header a{color:var(--cream);opacity:.8;text-decoration:none}
.resbar button{font:inherit;font-size:13px;border:0;padding:5px 10px;margin-left:4px;border-radius:3px;background:#2b3e46;color:var(--cream);cursor:pointer}
.resbar button.on{background:var(--edge)}
main{max-width:1500px;margin:0 auto;padding:24px 32px 80px}section{margin:44px 0}h2{font-size:26px;margin:0 0 2px}h3{font-size:15px;margin:24px 0 6px;opacity:.75}
.take{margin:0 0 14px;max-width:900px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}
figure{margin:0}figcaption{font-size:13px;font-weight:600;opacity:.7;margin-bottom:4px}img{width:100%;display:block;border-bottom:3px solid var(--edge)}
figure.none p{background:#e6d8bc;padding:40px;text-align:center;margin:0;opacity:.6}
.lede{max-width:900px;font-size:17px}
</style></head><body><header><h1>Spillway R18 interface</h1><nav>''' + ''.join(nav) + '''</nav><div class="resbar">''' + ''.join(
        '<button data-res="%s">%s</button>' % (r, r.replace('x', '×')) for r in RES) + '''</div></header><main>
<p class="lede">One interface language for Look C: Bricolage Grotesque throughout, cream sheets with ink type and an orange edge for anything you read, cream numbers with a thin ink outline for anything you glance at, and nothing in the middle of the screen. Blocks sit inside a centred 16:9 frame, so on the ultrawide they stay near the eye. Telemetry moved behind F9. Click any image for full size; originals are PNGs under ~/.cache/spillway-r18/shots.</p>
''' + ''.join(sections) + '''</main><script>
const show=r=>{document.querySelectorAll('.res').forEach(e=>e.style.display=e.dataset.res===r?'':'none');document.querySelectorAll('.resbar button').forEach(b=>b.classList.toggle('on',b.dataset.res===r))};
document.querySelectorAll('.resbar button').forEach(b=>b.onclick=()=>show(b.dataset.res));show('3440x1440');
</script></body></html>'''
    (OUT / 'index.html').write_text(page)
    print(OUT / 'index.html')


if __name__ == '__main__':
    main()
