#!/usr/bin/env python3
"""red/green engine fixtures for the four release-helper corrections; no pack acceptance."""
import argparse
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
OLD = '406640de38a041c86471ab69172e74f2b38f7e84'
HELPERS = ['tools/package-r15.py', 'tools/r14_native_display.py', 'tools/momentum-tape.py', 'tools/r15-pack-probe.gd']


def load(path):
    spec = importlib.util.spec_from_file_location('r15_fix_owner', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--identity', type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    identity = json.loads(args.identity.read_text())['identity']
    results = []
    hashes = {}
    with tempfile.TemporaryDirectory(prefix='r15-fix-fixtures-') as temp:
        temp = Path(temp)
        for variant in ['old', 'fixed']:
            folder = temp / variant
            for rel in HELPERS:
                data = (subprocess.check_output(['git', 'show', OLD + ':projects/foldrunner/' + rel], cwd=PROJECT)
                        if variant == 'old' else (PROJECT / rel).read_bytes())
                target = folder / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                hashes[variant + '/' + rel] = hashlib.sha256(data).hexdigest()
            owner = load(folder / 'tools/package-r15.py')
            mini = folder / 'mini'
            mini.mkdir()
            (mini / 'project.godot').write_text('[application]\nconfig/name="R15 helper corrections"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            shutil.copy2(folder / 'tools/r15-pack-probe.gd', mini / 'probe.gd')
            shutil.copy2(PROJECT / 'tests/r15_verifier_fixes.gd.in', mini / 'review.gd')
            output = args.out / (variant + '.json')
            cmd = [owner.EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', mini,
                   '--script', 'res://review.gd', '--', '--out=' + str(output)]
            code, text = owner.run_engine(cmd, mini, owner.engine_env(folder / 'profile'), args.out / (variant + '.log'), 45)
            assert code == 0 and not owner.ERRORS.search(text), (variant, code, text)
            observations = {r['name']: r['value'] for r in json.loads(output.read_text())}
            expected = {'complete label admitted': True, 'zero character label admitted': False,
                        'hidden label admitted': False, 'transparent label admitted': False,
                        'one character label admitted': variant == 'old', 'clipped label admitted': variant == 'old',
                        'partially clipped label admitted': variant == 'old',
                        'opaque floor triangle': 'ReviewFloor', 'hidden floor triangle': '',
                        'transparent floor triangle': 'ReviewFloor' if variant == 'old' else '',
                        'mixed visible vertex count': 6 if variant == 'old' else 3,
                        'mixed transparent triangle': 'ReviewFloor' if variant == 'old' else '',
                        'mixed opaque triangle': 'ReviewFloor', 'mixed opaque surface': -1 if variant == 'old' else 1,
                        'opaque next pass triangle': 'ReviewFloor', 'integer tick array admitted': True,
                        'float tick array admitted': False, 'bool tick admitted': False,
                        'truncated tick array admitted': False, 'changed tick array admitted': False}
            for name, want in expected.items():
                results.append({'variant': variant, 'name': name, 'ok': observations[name] == want,
                                'actual': observations[name], 'expected': want})
            pack = folder / (owner.NAME + '.pck')
            pack.write_bytes(b'fixture only')
            settings = SimpleNamespace(pack_required=[], require=['res://explicit.gd'])
            where = {'map': 'whiteout-relay', 'preset': 'server128'}
            required = owner.spec_for('play', folder, folder, settings, identity, {}, where)['expect']['loaded_required']
            for name, actual, want in [
                ('Whiteout level requested', identity['maps']['whiteout-relay']['level_script'] in required, True),
                ('Whiteout textures requested', set(identity['maps']['whiteout-relay']['textures']) <= set(required), variant == 'fixed'),
                ('unrelated Breakwater sky not requested', 'res://assets/r15/breakwater/sky/industrial_sunset_02_puresky_2k.hdr' not in required, variant == 'fixed'),
                ('generated shader sentinel not required', '<built-in>' not in required, True),
                ('explicit required module retained', 'res://explicit.gd' in required, True)]:
                results.append({'variant': variant, 'name': name, 'ok': actual == want, 'actual': actual, 'expected': want})
            archive = io.BytesIO()
            with tarfile.open(fileobj=archive, mode='w') as tar:
                for name in ['tools/r15-pack-probe.gd', 'tools/momentum-tape.py']:
                    data = b'fixture'; info = tarfile.TarInfo(name); info.size = len(data); tar.addfile(info, io.BytesIO(data))
            for failure in ['success', 'import-refused', 'import-cancel', 'route-refused', 'route-cancel']:
                evidence = folder / failure
                evidence.mkdir()
                def imported(*_a, **_k):
                    (evidence / 'source-freeze/.godot/imported').mkdir(parents=True)
                    (evidence / 'freeze-profile/cache').mkdir(parents=True, exist_ok=True)
                    (evidence / 'freeze-import.log').write_text('import fixture\n')
                    if failure == 'import-refused': raise owner.Rejected('import fixture')
                    if failure == 'import-cancel': raise KeyboardInterrupt('import fixture')
                def route(*_a, **_k):
                    if failure == 'route-refused': raise owner.Rejected('route fixture')
                    if failure == 'route-cancel': raise KeyboardInterrupt('route fixture')
                    return {'fixture': True}
                settings = SimpleNamespace(route=[{}])
                with patch.object(owner, 'git', return_value=str(PROJECT)), patch.object(owner, 'source_archive', return_value=archive.getvalue()), patch.object(owner, 'checked', imported), patch.object(owner, 'source_route', route):
                    try: owner.recheck_routes({'source_commit': OLD, 'source_project_path': 'projects/foldrunner', 'identity': {}}, settings, evidence)
                    except (owner.Rejected, KeyboardInterrupt): pass
                clean = not (evidence / 'source-freeze').exists()
                want = variant == 'fixed' or failure == 'success'
                results.append({'variant': variant, 'name': failure + ' removes freeze', 'ok': clean == want, 'actual': clean, 'expected': want})
                if variant == 'fixed':
                    results.append({'variant': variant, 'name': failure + ' removes import profile', 'ok': not (evidence / 'freeze-profile').exists()})
            # execute the real check-command branch with a controlled replay refusal/cancel.
            for failure in ['refused', 'cancel']:
                evidence = folder / ('main-' + failure)
                package = folder / 'package'; package.mkdir(exist_ok=True)
                (package / 'BUILD.json').write_text(json.dumps({'source_commit': OLD, 'source_project_path': 'projects/foldrunner'}))
                settings = ['package-r15.py', 'check', str(package), '--evidence', str(evidence), '--scratch', str(folder),
                            '--route', 'map=whiteout-relay,preset=server128,tape=/tmp/fixture.json']
                error = owner.Rejected('main fixture') if failure == 'refused' else KeyboardInterrupt('main fixture')
                with patch.object(sys, 'argv', settings), patch.object(owner, 'git', return_value='scripts/r15_main.gd'), patch.object(owner, 'recheck_routes', side_effect=error):
                    try: owner.main()
                    except SystemExit as exit_code: assert exit_code.code in (1, 130)
                leftovers = list(folder.glob('r15-check-*'))
                results.append({'variant': variant, 'name': 'main ' + failure + ' removes work', 'ok': bool(leftovers) == (variant == 'old')})
                for leftover in leftovers: shutil.rmtree(leftover)
    report = {'ok': all(r['ok'] for r in results), 'checks': results, 'executed_sha256': hashes,
              'reviewed_parent': OLD, 'scope': 'headless actual probe predicates and actual Python cleanup/spec callers; old faults reproduced, repaired behavior asserted; no export/native/package verdict', 'scratch_removed': not temp.exists()}
    (args.out / 'RESULTS.json').write_text(json.dumps(report, indent=2) + '\n')
    print(len(results), 'expectations,', sum(not r['ok'] for r in results), 'unmet')
    for r in results:
        if not r['ok']: print(r)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
