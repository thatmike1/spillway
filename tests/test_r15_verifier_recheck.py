#!/usr/bin/env python3
"""independent focused boundary review; failing assertions are retained counterexamples."""
import argparse
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
from types import SimpleNamespace
from unittest.mock import patch

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
COMMIT = '03d970bed5fac9ced3181b25fc2137203a052d3f'
HELPERS = ['tools/package-r15.py', 'tools/r15-pack-probe.gd', 'tools/r14_native_display.py', 'tools/momentum-tape.py']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    spec = importlib.util.spec_from_file_location('recheck_owner', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    global COMMIT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--identity', type=Path, required=True)
    parser.add_argument('--commit', default=COMMIT, help='reviewed helper commit, or worktree for a labelled repair check')
    args = parser.parse_args()
    COMMIT = args.commit
    args.out.mkdir(parents=True, exist_ok=False)
    checks, commands, signals = [], [], []

    def check(name, actual, expected=True, detail=None):
        checks.append(dict(name=name, actual=actual, expected=expected, ok=actual == expected, detail=detail))

    identity = json.loads(args.identity.read_text())['identity']
    hashes = {}
    with tempfile.TemporaryDirectory(prefix='r15-verifier-recheck-') as temporary:
        temp = Path(temporary)
        frozen = temp / 'frozen'
        for name in HELPERS:
            data = (PROJECT / name).read_bytes() if COMMIT == 'worktree' else subprocess.check_output(['git', 'show', COMMIT + ':projects/foldrunner/' + name], cwd=PROJECT)
            target = frozen / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            hashes[name] = sha(target)
            check('reviewed helper matches checkout: ' + name, sha(PROJECT / name), hashes[name])
        owner = load(frozen / 'tools/package-r15.py')
        check('pinned editor digest', sha(owner.EDITOR), owner.EDITOR_SHA256)
        source_receipt = {'reviewed_commit': COMMIT, 'checkout_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip(),
            'project_tree': None if COMMIT == 'worktree' else subprocess.check_output(['git', 'rev-parse', COMMIT + ':projects/foldrunner'], cwd=PROJECT, text=True).strip(),
            'helpers_sha256': hashes, 'editor': {'path': str(owner.EDITOR), 'sha256': sha(owner.EDITOR)},
            'python': {'path': sys.executable, 'sha256': sha(sys.executable)},
            'tests_sha256': {str(p.relative_to(PROJECT)): sha(p) for p in [Path(__file__), Path(__file__).with_name('r15_verifier_recheck.gd.in')]},
            'identity': {'path': str(args.identity), 'sha256': sha(args.identity)}}
        (args.out / 'SOURCES.json').write_text(json.dumps(source_receipt, indent=2) + '\n')
        mini = temp / 'mini'
        mini.mkdir()
        (mini / 'project.godot').write_text('[application]\nconfig/name="R15 independent verifier recheck"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        shutil.copy2(frozen / 'tools/r15-pack-probe.gd', mini / 'probe.gd')
        shutil.copy2(Path(__file__).with_name('r15_verifier_recheck.gd.in'), mini / 'review.gd')
        argv = [owner.EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', mini, '--script', 'res://review.gd', '--', '--out=' + str(args.out / 'GODOT.json')]
        commands.append([str(a) for a in argv])
        code, text = owner.run_engine(argv, mini, owner.engine_env(temp / 'profile'), args.out / 'godot.log', 25)
        check('headless exact probe fixture exits cleanly', code == 0 and not owner.ERRORS.search(text), detail=text[-1000:])
        if (args.out / 'GODOT.json').exists():
            checks.extend(json.loads((args.out / 'GODOT.json').read_text()))

        # the old helper is a control for the newly refused opaque scissor case only.
        old_commit = '406640de38a041c86471ab69172e74f2b38f7e84'
        old_probe = subprocess.check_output(['git', 'show', old_commit + ':projects/foldrunner/tools/r15-pack-probe.gd'], cwd=PROJECT)
        (mini / 'probe.gd').write_bytes(old_probe)
        old_output = args.out / 'OLD-GODOT.json'
        argv = [owner.EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', mini, '--script', 'res://review.gd', '--', '--out=' + str(old_output)]
        commands.append([str(a) for a in argv])
        code, text = owner.run_engine(argv, mini, owner.engine_env(temp / 'old-profile'), args.out / 'old-godot.log', 25)
        check('old-helper regression control exits cleanly', code == 0 and not owner.ERRORS.search(text), detail=text[-1000:])
        if old_output.exists():
            old_rows = {r['name']: r for r in json.loads(old_output.read_text())}
            check('old helper admits the opaque low-alpha scissor floor', old_rows['low-alpha opaque scissor floor admitted']['actual'], 'Floor')
        (args.out / 'OLD-CONTROL.json').write_text(json.dumps({'commit': old_commit, 'probe_sha256': hashlib.sha256(old_probe).hexdigest(),
            'scope': 'only the clean runner and opaque low-alpha scissor observation are asserted; other raw old observations are not acceptance results'}, indent=2) + '\n')
        shutil.copy2(frozen / 'tools/r15-pack-probe.gd', mini / 'probe.gd')

        # compare all allowed map/preset pairs against an independently constructed set.
        pack = temp / (owner.NAME + '.pck')
        pack.write_bytes(b'component only')
        settings = SimpleNamespace(pack_required=['res://pack-only.json'], require=['res://explicit.gd'])
        shared = {identity[k] for k in ['main_script', 'hud_script', 'stats_script', 'audio_script']}
        for map_id, pairs in identity['keys'].items():
            for preset, pair in pairs.items():
                world = identity['maps'][map_id]
                expected = shared | set(pair['runner_chain']) | {world['level_script']} | set(world['textures']) | set(world['shaders'])
                expected = {p for p in expected if p.startswith('res://')} | {'res://explicit.gd'}
                for mode in ['play', 'reload']:
                    spec = owner.spec_for(mode, temp, temp, settings, identity, {}, dict(map=map_id, preset=preset))
                    check(mode + ' selected resources ' + map_id + '/' + preset, set(spec['expect']['loaded_required']), expected)
                    # sets are serialized below, but comparisons here stay exact.
                    checks[-1]['actual'] = sorted(checks[-1]['actual'])
                    checks[-1]['expected'] = sorted(checks[-1]['expected'])
                    check(mode + ' pack coverage retained ' + map_id + '/' + preset, spec['expect']['pack_required'], settings.pack_required)
        startup = owner.spec_for('controls', temp, temp, settings, identity, {})
        check('controls retain all original startup requirements', startup['expect']['loaded_required'], sorted(set(identity['loaded_at_start']) | set(settings.require)))
        seeded = copy.deepcopy(identity)
        seeded['maps']['whiteout-relay']['shaders'] += ['<built-in>', 'res://review_shader.gdshader']
        seeded['maps']['whiteout-relay']['textures'] += ['res://review_texture.png']
        required = owner.spec_for('play', temp, temp, settings, seeded, {}, dict(map='whiteout-relay', preset='server128'))['expect']['loaded_required']
        check('generated sentinel excluded', '<built-in>' in required, False)
        check('real selected shader retained', 'res://review_shader.gdshader' in required)
        check('real selected texture retained', 'res://review_texture.png' in required)

        # the lab advertises its experimental status in the actual OS window title.
        title_out = temp / 'title-controls'
        (title_out / 'cwd').mkdir(parents=True)
        for map_id, pairs in identity['keys'].items():
            for preset, pair in pairs.items():
                wanted = 'Spillway R15 · %s · %s · %s Hz' % (identity['maps'][map_id]['name'], identity['registry']['presets'][preset]['label'], pair['physics_hz'])
                lab = pair['map_kind'] == 'lab'
                if lab:
                    wanted += ' · EXPERIMENTAL'
                for correct in [True, False]:
                    supplied = wanted if correct else (wanted.removesuffix(' · EXPERIMENTAL') if lab else wanted + ' · EXPERIMENTAL')
                    actual_checks = []
                    owner._common(lambda name, ok, *detail: actual_checks.append((name, ok)), 'title-fixture', 0, 'valid fixture log', {supplied}, title_out, identity, dict(map=map_id, preset=preset))
                    actual = next(ok for name, ok in actual_checks if name.endswith(': os window title'))
                    check(('complete title admitted ' if correct else 'incorrect experimental suffix refused ') + map_id + '/' + preset, actual, correct)

        # failure while copying helpers and corrupt archives still unwind the freeze.
        blob = io.BytesIO()
        with tarfile.open(fileobj=blob, mode='w') as tar:
            for name in ['tools/r15-pack-probe.gd', 'tools/momentum-tape.py']:
                data = (frozen / name).read_bytes()
                item = tarfile.TarInfo(name)
                item.size = len(data)
                tar.addfile(item, io.BytesIO(data))
        archive = blob.getvalue()
        build = dict(source_commit=COMMIT, source_project_path='projects/foldrunner', identity={})
        for phase in ['archive-read', 'bad-archive', 'probe-copy', 'observer-copy']:
            evidence = temp / ('cleanup-' + phase)
            evidence.mkdir()
            actual_copy = shutil.copy2
            def copying(src, dst, *a, **kw):
                if str(dst).endswith('frozen-probe.gd' if phase == 'probe-copy' else 'frozen-hull-observer.py'):
                    raise OSError('controlled copy failure')
                return actual_copy(src, dst, *a, **kw)
            def imported(*a, **kw):
                (evidence / 'source-freeze/.godot/imported').mkdir(parents=True)
                (evidence / 'freeze-import.log').write_text('preserved fixture log\n')
            try:
                with patch.object(owner, 'git', return_value=str(PROJECT)), patch.object(owner, 'source_archive', side_effect=OSError('archive read') if phase == 'archive-read' else None, return_value=b'bad' if phase == 'bad-archive' else archive), patch.object(owner, 'checked', imported), patch.object(owner.shutil, 'copy2', copying):
                    owner.recheck_routes(build, SimpleNamespace(route=[]), evidence)
            except (OSError, tarfile.TarError):
                outcome = 'refused'
            else:
                outcome = 'accepted'
            check(phase + ' refused', outcome, 'refused')
            check(phase + ' freeze removed', not (evidence / 'source-freeze').exists())
            check(phase + ' profile removed', not (evidence / 'freeze-profile').exists())
            if 'copy' in phase:
                check(phase + ' log retained', (evidence / 'freeze-import.log').read_text(), 'preserved fixture log\n')

        # signal the real check command in non-engine portions of its source recheck.
        for phase in ['extract', 'route']:
            for signal_name in ['SIGINT', 'SIGTERM']:
                folder = temp / (phase + '-' + signal_name)
                folder.mkdir()
                evidence = folder / 'evidence'
                package = folder / 'package'
                package.mkdir()
                (package / 'BUILD.json').write_text(json.dumps(build))
                (folder / 'archive.tar').write_bytes(archive)
                marker = folder / 'ready'
                wrapper = folder / 'wrapper.py'
                wrapper.write_text('''import importlib.util,sys,tarfile,time
from pathlib import Path
from unittest.mock import patch
sys.dont_write_bytecode = True
s=importlib.util.spec_from_file_location('owner', %r)
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
folder=Path(%r)
evidence=folder/'evidence'
phase=%r
def pause():
    (folder/'ready').write_text('ready')
    time.sleep(15)
def imported(*a,**k):
    (evidence/'source-freeze/.godot/imported').mkdir(parents=True)
    (evidence/'freeze-import.log').write_text('preserved import log\\n')
def route(*a,**k):
    pause()
    return {}
original=tarfile.TarFile.extractall
def extracted(self,*a,**k):
    result=original(self,*a,**k)
    if phase=='extract': pause()
    return result
sys.argv=['package-r15.py','check',str(folder/'package'),'--evidence',str(evidence),'--scratch',str(folder),'--route','map=whiteout-relay,preset=server128,tape=/tmp/recheck-component.json']
with patch.object(m,'git',return_value=%r),patch.object(m,'source_archive',return_value=(folder/'archive.tar').read_bytes()),patch.object(m,'checked',imported),patch.object(m,'source_route',route),patch.object(tarfile.TarFile,'extractall',extracted):
    m.main()
''' % (str(frozen / 'tools/package-r15.py'), str(folder), phase, str(PROJECT)))
                argv = [sys.executable, '-B', '-I', str(wrapper)]
                commands.append(argv)
                detail = {'phase': phase, 'signal': signal_name, 'wrapper_sha256': sha(wrapper), 'wrapper_source': wrapper.read_text()}
                with (args.out / (phase + '-' + signal_name + '.log')).open('wb') as log:
                    process = subprocess.Popen(argv, cwd=temp, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                    try:
                        end = time.monotonic() + 6
                        while not marker.exists() and process.poll() is None and time.monotonic() < end:
                            time.sleep(.02)
                        check(phase + '/' + signal_name + ' reached signal point', marker.exists())
                        if marker.exists():
                            os.kill(process.pid, getattr(signal, signal_name))
                        exit_code = process.wait(8)
                    finally:
                        if process.poll() is None:
                            os.killpg(process.pid, signal.SIGKILL)
                            process.wait(5)
                detail.update(exit=exit_code, freeze_left=(evidence / 'source-freeze').exists(), profile_left=(evidence / 'freeze-profile').exists(), work_left=[p.name for p in folder.glob('r15-check-*')], log_retained=(evidence / 'freeze-import.log').exists())
                signals.append(detail)
                check(phase + '/' + signal_name + ' cancellation exit', exit_code, 130)
                check(phase + '/' + signal_name + ' freeze removed', not detail['freeze_left'])
                check(phase + '/' + signal_name + ' profile removed', not detail['profile_left'])
                check(phase + '/' + signal_name + ' work removed', not detail['work_left'])
                if phase == 'route':
                    check(phase + '/' + signal_name + ' log preserved', detail['log_retained'])
        check('executed helper copies unchanged', all(sha(frozen / name) == value for name, value in hashes.items()))
        check('checkout helpers unchanged', all(sha(PROJECT / name) == value for name, value in hashes.items()))
    check('scratch removed', not Path(temporary).exists(), detail=temporary)
    (args.out / 'SIGNALS.json').write_text(json.dumps(signals, indent=2) + '\n')
    (args.out / 'COMMANDS.json').write_text(json.dumps({'invocation': [sys.executable, '-B', '-I', str(Path(__file__).resolve()), *sys.argv[1:]], 'commands': commands}, indent=2) + '\n')
    result = dict(checks=checks, passed=sum(c['ok'] for c in checks), failed=sum(not c['ok'] for c in checks), scratch_removed=not Path(temporary).exists(), scope='component counterexamples only; no export, native rendering, active candidate access or release acceptance')
    (args.out / 'RESULTS.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k:result[k] for k in ['passed','failed','scratch_removed']}))
    for row in checks:
        if not row['ok']:
            print('COUNTEREXAMPLE', row['name'], repr(row['actual']), 'expected', repr(row['expected']))
    return int(result['failed'] > 0)


if __name__ == '__main__':
    raise SystemExit(main())
