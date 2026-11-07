#!/usr/bin/env python3
"""negative controls for the r13 delivery tools: each packaging hazard must be refused.

preflight: a throwaway sparse clone of this repository gets one deliberate break per case
(default scene, build id, records file, missing preset, uncommitted edit) and
`package-overflow.py package --startup-only` must refuse it before writing a package.
contents and runtime: copies of a good package (from `package`) get one break each, with
checksums and manifests made consistent where the break is meant to reach the runtime, and
`package-overflow.py check` must fail. evidence goes to --evidence, outside Git.

python3 tests/test_overflow_delivery.py --package GOOD_PACKAGE_DIR --evidence NEW_DIR
    [--only preflight contents runtime integrity] [--display 167]
python3 tests/test_overflow_delivery.py --only integrity --evidence NEW_DIR
"""
import argparse
import copy
import hashlib
import io
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile

PROJECT = Path(__file__).resolve().parents[1]
TOOL = PROJECT / 'tools/package-overflow.py'
spec = importlib.util.spec_from_file_location('package_overflow', TOOL)
po = importlib.util.module_from_spec(spec)
spec.loader.exec_module(po)
STAGES = None
results = []


def check(name, ok, detail=''):
    results.append({'name': name, 'ok': bool(ok), 'detail': detail})
    print('%s %s%s' % ('PASS' if ok else 'FAIL', name, '' if not detail else ' (%s)' % str(detail)[:300]))


def run(cmd, cwd, log):
    result = subprocess.run([str(c) for c in cmd], cwd=cwd, capture_output=True, text=True)
    Path(log).write_text(result.stdout + result.stderr)
    return result


# --- preflight ---------------------------------------------------------------------------------

def preflight(evidence):
    top = Path(po.git('rev-parse', '--show-toplevel').strip())
    prefix = str(PROJECT.relative_to(top))
    clone = evidence / 'clone'
    subprocess.run(['git', 'clone', '-q', '--no-checkout', '--local', str(top), str(clone)], check=True)
    subprocess.run(['git', '-C', clone, 'sparse-checkout', 'set', prefix], check=True)
    subprocess.run(['git', '-C', clone, 'checkout', '-q', po.git('rev-parse', 'HEAD').strip()], check=True)
    for key in ['user.name', 'user.email']:
        subprocess.run(['git', '-C', clone, 'config', key, 'negative-control'], check=True)
    project = clone / prefix
    cases = [
        ('wrong default scene', 'project.godot', r'^run/main_scene=.*$', 'run/main_scene="res://scenes/main.tscn"', True, 'committed default scene'),
        ('wrong build id', 'scripts/momentum_overflow_main.gd', r'^const BUILD_ID := .*$', 'const BUILD_ID := "spillway-2026.11.06-r12"', True, 'committed BUILD_ID'),
        ('old records file', 'scripts/momentum_overflow_main.gd', r'^const SAVE_PATH := .*$', 'const SAVE_PATH := "user://spillway_r12.cfg"', True, 'committed records file'),
        ('missing export preset', 'export_presets.cfg', r'^name="Overflow Pack"$', 'name="Overflow Pack (renamed)"', True, 'no "Overflow Pack" preset'),
        ('uncommitted edit', 'scripts/momentum_overflow_level.gd', r'\Z', '\n# uncommitted\n', False, 'commit the project'),
    ]
    base = po.git('rev-parse', 'HEAD', cwd=clone).strip()
    for name, path, pattern, replacement, commit, expected in cases:
        subprocess.run(['git', '-C', clone, 'reset', '-q', '--hard', base], check=True)
        target = project / path
        text, count = re.subn(pattern, lambda _: replacement, target.read_text(), count=1, flags=re.M)
        target.write_text(text)
        if commit:
            subprocess.run(['git', '-C', clone, 'commit', '-qam', 'negative control: ' + name], check=True)
        out = evidence / ('preflight-' + name.replace(' ', '-'))
        result = run([sys.executable, '-I', project / 'tools/package-overflow.py', 'package', '--output', out / 'package',
                      '--stages', ','.join(STAGES), '--startup-only'], project, out.with_suffix('.log'))
        made = list((out / 'package').glob('*.zip')) if (out / 'package').exists() else []
        check('preflight refuses: ' + name, count == 1 and result.returncode == 1 and expected in result.stderr and not made,
              result.stderr.strip().splitlines()[-1] if result.stderr.strip() else result.returncode)
    shutil.rmtree(clone)


# --- tampered packages -------------------------------------------------------------------------

def integrity(evidence):
    """check declared provenance against git and the immutable runtime anchors."""
    top = Path(po.git('rev-parse', '--show-toplevel').strip())
    commit = po.git('rev-parse', 'HEAD').strip()
    prefix = str(PROJECT.relative_to(top))
    files = po.git('ls-tree', '-r', '--name-only', '--full-tree', commit + ':' + prefix, cwd=top).splitlines()
    archive = po.source_archive(commit, prefix, top)
    check('canonical source archive repeats exactly', archive == po.source_archive(commit, prefix, top))
    stamp = int(po.git('show', '-s', '--format=%ct', commit, cwd=top).strip())
    with tarfile.open(fileobj=io.BytesIO(archive)) as frozen:
        check('archive entry times equal the source commit', all(member.mtime == stamp for member in frozen.getmembers()))
    build = {'build': po.BUILD, 'main_scene': po.MAIN_SCENE, 'records_file': po.SAVE_PATH,
             'helpers_committed': True, 'export_editor_sha256': po.EDITOR_SHA256, 'export_preset': po.PRESET,
             'source_commit': commit, 'source_project_path': prefix,
             'source_tree': po.git('rev-parse', commit + ':' + prefix, cwd=top).strip(),
             'source_archive_sha256': hashlib.sha256(archive).hexdigest(), 'source_files': len(files),
             'helpers_sha256': {p: hashlib.sha256(po.git('show', commit + ':' + prefix + '/' + p, binary=True, cwd=top)).hexdigest() for p in po.HELPERS},
             'runtime': {'archive_sha256': po.TEMPLATES_SHA256}, 'course_key': '0123456789abcdef'}
    check('valid source provenance resolves', po.verify_source_manifest(build) == files)
    for key, value in [('source_tree', '0' * 40), ('source_archive_sha256', '0' * 64),
                       ('source_files', -1), ('helpers_sha256', {}), ('helpers_committed', False),
                       ('records_file', 'user://spillway_r12.cfg'), ('course_key', 'deadbeef')]:
        changed = copy.deepcopy(build)
        changed[key] = value
        try:
            po.verify_source_manifest(changed)
        except po.Rejected as error:
            check('reject changed provenance: ' + key, True, str(error))
        else:
            check('reject changed provenance: ' + key, False)
    fake = evidence / 'fake-template-cache'
    fake.mkdir()
    provenance = json.loads((po.TEMPLATES / 'PROVENANCE.json').read_text())
    for name in po.TEMPLATE_MEMBERS:
        (fake / name).write_bytes(b'not an engine\n')
        provenance['members']['templates/' + name] = po.digest(fake / name)
    (fake / 'PROVENANCE.json').write_text(json.dumps(provenance))
    (fake / 'version.txt').write_text('4.7.2.stable\n')
    actual = po.TEMPLATES
    try:
        po.TEMPLATES = fake
        try:
            po.templates()
        except po.Rejected as error:
            check('reject self-attested replacement runtimes', True, str(error))
        else:
            check('reject self-attested replacement runtimes', False)
    finally:
        po.TEMPLATES = actual

def unpack(package, work):
    shutil.copytree(package, work, ignore=shutil.ignore_patterns('evidence', 'rejected'))
    folders = {}
    for z in sorted(work.glob('*.zip')):
        po.extract(z, work / 'unzipped')
        platform = 'linux-x86_64' if '-linux-' in z.name else 'windows-x86_64'
        folder = work / 'unzipped' / ('%s-%s' % (po.NAME, platform))
        folders[z] = folder
    return folders


def repack(work, folders, pack=None):
    if pack:
        manifest = json.loads((work / 'BUILD.json').read_text())
        manifest['pack_sha256'] = po.digest(pack)
        (work / 'BUILD.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    for z, folder in folders.items():
        if pack is not None:
            shutil.copy2(pack, folder / (po.NAME + '.pck'))
            manifest = json.loads((folder / 'BUILD.json').read_text())
            manifest['pack_sha256'] = po.digest(pack)
            (folder / 'BUILD.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
        z.unlink()
        po.archive(folder, z)
    (work / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (po.digest(z), z.name) for z in folders))
    shutil.rmtree(work / 'unzipped')


def checker(work, evidence, name, expected):
    out = evidence / ('check-' + name)
    result = run([sys.executable, '-I', TOOL, 'check', work, '--evidence', out, '--stages', ','.join(STAGES),
                  '--display', str(ARGS.display)], PROJECT, str(out) + '.log')
    failed = [line for line in result.stdout.splitlines() if line.startswith('FAIL')]
    check('check refuses: ' + name, result.returncode == 1 and any(expected in line for line in failed), failed[:4])
    shutil.rmtree(work)


def contents(package, evidence):
    work = evidence / 'pkg-override'
    folders = unpack(package, work)
    linux = next(f for z, f in folders.items() if 'linux' in z.name)
    (linux / 'override.cfg').write_text('[application]\nrun/main_scene="res://scenes/main.tscn"\n')
    repack(work, folders)
    checker(work, evidence, 'override.cfg beside the runtime', 'nothing but runtime')
    work = evidence / 'pkg-loose'
    folders = unpack(package, work)
    linux = next(f for z, f in folders.items() if 'linux' in z.name)
    (linux / 'scripts').mkdir()
    shutil.copy2(PROJECT / 'scripts/momentum_overflow_hud.gd', linux / 'scripts/momentum_overflow_hud.gd')
    repack(work, folders)
    checker(work, evidence, 'loose source script in the folder', 'nothing but runtime')
    work = evidence / 'pkg-tampered'
    folders = unpack(package, work)
    for folder in folders.values():
        with open(folder / (po.NAME + '.pck'), 'r+b') as stream:
            stream.seek(-1, 2)
            last = stream.read(1)
            stream.seek(-1, 2)
            stream.write(bytes([last[0] ^ 1]))
    repack(work, folders)
    checker(work, evidence, 'pack differs from its manifest', 'manifest names this pack')
    work = evidence / 'pkg-sums'
    shutil.copytree(package, work, ignore=shutil.ignore_patterns('evidence', 'rejected'))
    sums = (work / 'SHA256SUMS').read_text()
    (work / 'SHA256SUMS').write_text(sums.replace(sums[:8], '00000000', 1))
    checker(work, evidence, 'zip checksum mismatch', 'zip checksums match')


def variant_pack(package, evidence, name, path, pattern, replacement, preset_exclude=None):
    """a pack exported from the package's own commit with one deliberate source break."""
    build = json.loads((package / 'BUILD.json').read_text())
    top = Path(po.git('rev-parse', '--show-toplevel').strip())
    source = evidence / ('variant-' + name) / 'source'
    source.mkdir(parents=True)
    tar = source.parent / 'source.tar'
    tar.write_bytes(po.git('archive', '--format=tar', '%s:%s' % (build['source_commit'], build['source_project_path']), binary=True, cwd=top))
    with tarfile.open(tar) as frozen:
        frozen.extractall(source, filter='data')
    tar.unlink()
    if path:
        target = source / path
        target.write_text(re.sub(pattern, lambda _: replacement, target.read_text(), count=1, flags=re.M))
    if preset_exclude:
        presets = source / 'export_presets.cfg'
        presets.write_text(re.sub(r'(name="Overflow Pack"[\s\S]*?exclude_filter=")', r'\g<1>' + preset_exclude + ',', presets.read_text(), count=1))
    env = po.engine_env(source.parent / 'profile')
    po.checked([po.EDITOR, '--headless', '--path', source, '--import'], source, env, source.parent / 'import.log')
    pack = source.parent / (po.NAME + '.pck')
    po.checked([po.EDITOR, '--headless', '--path', source, '--export-pack', po.PRESET, pack], source, env, source.parent / 'export.log')
    shutil.rmtree(source)
    return pack


def runtime(package, evidence):
    pack = variant_pack(package, evidence, 'no-hud', None, None, None, preset_exclude='scripts/momentum_overflow_hud.gd')
    work = evidence / 'pkg-no-hud'
    repack(work, unpack(package, work), pack)
    checker(work, evidence, 'pack without the r13 hud module', 'shipped binary starts the r13 scene')
    pack = variant_pack(package, evidence, 'r12-records', 'scripts/momentum_overflow_main.gd', r'^const SAVE_PATH := .*$',
                        'const SAVE_PATH := "user://spillway_r12.cfg"')
    work = evidence / 'pkg-r12-records'
    repack(work, unpack(package, work), pack)
    checker(work, evidence, 'pack writing the r12 records file', 'records namespace')


def main():
    global STAGES, ARGS
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--package', type=Path)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--only', nargs='*', choices=['preflight', 'contents', 'runtime', 'integrity'])
    parser.add_argument('--display', type=int, default=167)
    ARGS = parser.parse_args()
    if ARGS.package is None and ARGS.only != ['integrity']:
        parser.error('--package is required except for --only integrity')
    package, evidence = ARGS.package.resolve() if ARGS.package else None, ARGS.evidence.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        sys.exit('evidence directory must be new or empty')
    evidence.mkdir(parents=True, exist_ok=True)
    STAGES = json.loads((package / 'BUILD.json').read_text())['stages'] if package else None
    for group, function in [('preflight', lambda: preflight(evidence)), ('contents', lambda: contents(package, evidence)),
                            ('runtime', lambda: runtime(package, evidence)), ('integrity', lambda: integrity(evidence))]:
        if not ARGS.only or group in ARGS.only:
            function()
    (evidence / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
    failures = [r for r in results if not r['ok']]
    print('%d delivery controls, %d failed' % (len(results), len(failures)))
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
