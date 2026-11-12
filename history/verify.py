#!/usr/bin/env python3
"""read-only verification of the merged historical material, independent of archive mounts."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'MANIFEST.json').read_text())
errors = []
counts = {}
seen = set()
source_checks = {'available_and_matched': 0, 'unavailable_external_original': 0, 'commit_or_archive_reference': 0}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


for item in manifest['frames']:
    rel = Path(item['file'])
    path = root / rel
    if rel.is_absolute() or '..' in rel.parts or not rel.as_posix().startswith('rounds/'):
        errors.append('unsafe image path: ' + str(rel))
    if rel.as_posix() in seen:
        errors.append('duplicate image path: ' + str(rel))
    seen.add(rel.as_posix())
    rid = item['round']
    counts[rid] = counts.get(rid, 0) + 1
    if not path.is_file():
        errors.append('missing image: ' + str(rel))
        continue
    if digest(path) != item['output_sha256']:
        errors.append('output hash mismatch: ' + str(rel))
    actual = subprocess.check_output(['identify', '-format', '%m %w %h', str(path)], text=True).split()
    if actual[0] != 'WEBP' or int(actual[1]) != 1600 or list(map(int, actual[1:])) != item['dimensions']:
        errors.append('decode/dimensions mismatch: ' + str(rel))
    for key in ['source_path', 'what_it_shows', 'how_made', 'provenance']:
        if not item.get(key):
            errors.append('missing ' + key + ': ' + str(rel))
    source = Path(item['source_path'])
    if source.is_file():
        if item.get('source_sha256') and digest(source) != item['source_sha256']:
            errors.append('available source hash mismatch: ' + str(source))
        source_checks['available_and_matched'] += 1
    elif source.is_absolute():
        source_checks['unavailable_external_original'] += 1
    else:
        source_checks['commit_or_archive_reference'] += 1

actual_files = {p.relative_to(root).as_posix() for p in (root / 'rounds').glob('r*/frames/*') if p.is_file()}
if actual_files != seen:
    errors.append('manifest membership differs from actual frames: ' + str(actual_files ^ seen))
for n in range(1, 22):
    rid = f'r{n:02}'
    if counts.get(rid, 0) == 0:
        errors.append('no frames for ' + rid)
    notes = root / 'rounds' / rid / 'notes.md'
    if not notes.is_file() or 'archive placeholder' in notes.read_text().lower():
        errors.append('missing/completed notes for ' + rid)
    if n <= 11:
        for name in ['build.json', 'commits.txt']:
            if not (notes.parent / name).is_file():
                errors.append('missing desktop archival file: ' + rid + '/' + name)

for item in json.loads((root / 'SOURCES.json').read_text()):
    path = root / item['file']
    if not path.is_file() or digest(path) != item['sha256']:
        errors.append('copied source snapshot mismatch: ' + item['file'])

for doc in [root / 'TIMELINE.md', *(root / 'rounds').glob('r*/notes.md')]:
    for target in re.findall(r'\]\(([^)]+)\)', doc.read_text()):
        if target.startswith(('https:', 'http:', '#', 't3-thread:')):
            continue
        if not (doc.parent / target.split('#')[0]).exists():
            errors.append('broken curated link: ' + str(doc.relative_to(root)) + ': ' + target)
sections = re.findall(r'^## R(\d\d):', (root / 'TIMELINE.md').read_text(), flags=re.M)
if sections != [f'{n:02}' for n in range(1, 22)]:
    errors.append('timeline round order/coverage mismatch: ' + str(sections))
for name, receipt in manifest.get('fresh_capture_receipts', {}).items():
    if not receipt.get('display_released'):
        errors.append('unclean private display: ' + name)
    if min(receipt['home_free_before'], receipt['home_free_after']) < 15_000_000_000:
        errors.append('home reserve receipt below floor: ' + name)

size = sum(p.stat().st_size for p in root.rglob('*') if p.is_file())
if size >= 150_000_000:
    errors.append('history exceeds 150 MB')
result = {
    'passed': not errors,
    'round_counts': counts,
    'frame_count': len(manifest['frames']),
    'history_bytes_at_check': size,
    'budget_bytes': 150_000_000,
    'checks': ['21 rounds with frames and notes', 'one ordered timeline section per numbered round', 'manifest membership and relative image paths', 'all output hashes and WebP decodes at 1600 px width', 'available original source hashes', 'copied desktop source snapshot hashes', 'curated Markdown links', 'private-display cleanup and HOME reserve receipts', 'total history budget'],
    'source_checks': source_checks,
    'external_source_limit': 'The desktop archive drive is unavailable here. Its source-machine verification is retained in VERIFICATION-r01-r11-desktop.json, not reissued as a laptop source check. Stream-restored archive frames were individually hashed before conversion; rebuilt source references are not historical ZIP identities.',
    'known_gaps': manifest['gaps'],
    'errors': errors,
}
print(json.dumps(result, indent=2, ensure_ascii=False))
sys.exit(0 if not errors else 1)
