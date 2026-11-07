#!/usr/bin/env python3
"""package the committed r13 overflow game on official godot 4.7.2 release runtimes.

package: freeze HEAD's project tree with git archive, import and export the Overflow pack in
that copy, put the pack beside the official Linux and Windows release templates, then run
`check` on the zips before anything is published to --output. it refuses a dirty project,
a default scene, build id or records file other than r13's, and a missing export preset; it
never repairs project config. check: verify published zips from empty directories with the
shipped Linux runtime (tools/check-overflow-pack.sh wraps it). docs/momentum/DELIVERY.md.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import threading
import time
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
PROBE = PROJECT / 'tools/overflow-pack-probe.gd'
CACHE = Path.home() / '.local/share/foldrunner'
EDITOR = CACHE / 'godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
TEMPLATES = CACHE / 'godot-4.7.2-templates'
LICENCES = CACHE / 'godot-4.7.2/licenses'
# official 4.7.2-stable release: the linux editor zip member and the export templates archive
# (github asset digest and SHA512-SUMS.txt agree), and LICENSE.txt / COPYRIGHT.txt at the tag.
ENGINE_VERSION = '4.7.2.stable.official.ed1daf0bf'
EDITOR_SHA256 = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
TEMPLATES_SHA256 = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
LICENCE_SHA256 = {'GODOT-LICENSE.txt': 'b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80',
                  'GODOT-COPYRIGHT.txt': 'cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d'}

# p / what this tool ships. a later round changes these on purpose, not by inference.
BUILD = 'spillway-2026.11.07-r13-overflow'
MAIN_SCENE = 'res://scenes/momentum_overflow.tscn'
MAIN_SCRIPT = 'res://scripts/momentum_overflow_main.gd'
SAVE_PATH = 'user://spillway_r13.cfg'
PRESET = 'Overflow Pack'
NAME = 'SpillwayR13'
TITLE = 'Spillway R13 · Overflow'
STARTUP = re.compile(r'^r13 overflow: build=(?P<build>[^;]+); course=(?P<course>[^;]+); stages=(?P<stages>\d+); '
                     r'course_key=(?P<key>[0-9a-f]+); records=(?P<records>[^;]+); runner=(?P<runner>[^;]+); '
                     r'renderer=(?P<renderer>\S+)$', re.M)
EXPECT = {'build': BUILD, 'main_scene': MAIN_SCENE, 'main_script': MAIN_SCRIPT, 'save_path': SAVE_PATH, 'persist': True,
          'level_script': 'res://scripts/momentum_overflow_level.gd',
          'runner_script': 'res://scripts/momentum_carry_air_candidate.gd',
          'runner_base': 'res://scripts/momentum_carry_player.gd', 'runner_policy': 'carry-air-candidate',
          'hud_script': 'res://scripts/momentum_overflow_hud.gd', 'audio_script': 'res://scripts/momentum_overflow_audio.gd',
          'hud_required': ['SPILLWAY', 'OVERFLOW  ·  R13'], 'hud_forbidden': ['R12', 'surf', 'debug'],
          'pack_forbidden_prefixes': ['res://tests/', 'res://tools/', 'res://docs/', 'res://builds/'],
          'material_shader': 'res://shaders/momentum_surface.gdshader', 'asset_prefix': 'res://assets/momentum/'}
# modules the running game must have loaded; --require adds new ones (an art module, say).
LOADED = [MAIN_SCRIPT, EXPECT['level_script'], EXPECT['runner_script'], EXPECT['runner_base'], EXPECT['hud_script'],
          EXPECT['audio_script'], 'res://scripts/momentum_materials.gd', EXPECT['material_shader']]
# committed files that must ship inside the pack: everything a game resource could be.
SHIPPED_DIRS = ('scripts/', 'scenes/', 'shaders/', 'assets/', 'data/')
SHIPPED_EXT = ('.gd', '.tscn', '.tres', '.gdshader', '.png', '.jpg', '.webp', '.gltf', '.glb', '.ogg', '.wav', '.json')
WINDOWS = {'SpillwayR13.exe': 'windows_release_x86_64.exe', 'SpillwayR13.console.exe': 'windows_release_x86_64_console.exe'}
LINUX = {'SpillwayR13.x86_64': 'linux_release.x86_64'}
ERRORS = re.compile(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:|Failed to load', re.M)


class Rejected(Exception):
    pass


def digest(path):
    value = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            value.update(block)
    return value.hexdigest()


def git(*args, binary=False, cwd=PROJECT):
    result = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True)
    if result.returncode:
        raise Rejected('git %s failed: %s' % (' '.join(args), result.stderr.decode(errors='replace')))
    return result.stdout if binary else result.stdout.decode()


def engine_env(root, display=None):
    # a fresh environment: no parent display, wayland socket or desktop profile reaches the game.
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'HOME': str(Path.home()), 'LANG': 'C.UTF-8'}
    for name in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
        path = root / name.split('_')[1].lower()
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        env[name] = str(path)
    if display is not None:
        env['DISPLAY'] = ':%d' % display
    return env


def run_engine(cmd, cwd, env, log, deadline, watch=None):
    """run one owned engine process group to completion or deadline; returns (code, text)."""
    with open(log, 'wb') as output:
        process = subprocess.Popen([str(c) for c in cmd], cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        watcher = threading.Thread(target=watch, args=(process,), daemon=True) if watch else None
        if watcher:
            watcher.start()
        try:
            code = process.wait(deadline)
        except subprocess.TimeoutExpired:
            for sig, wait in [(signal.SIGTERM, 10), (signal.SIGKILL, 10)]:
                try:
                    os.killpg(process.pid, sig)
                    process.wait(wait)
                    break
                except (subprocess.TimeoutExpired, ProcessLookupError):
                    continue
            code = 'timeout'
        if watcher:
            watcher.join(5)
    return code, Path(log).read_text(errors='replace')


def checked(cmd, cwd, env, log, deadline=600):
    code, text = run_engine(cmd, cwd, env, log, deadline)
    if code != 0 or ERRORS.search(text):
        raise Rejected('%s failed (exit %s); see %s' % (Path(str(cmd[0])).name, code, log))
    return text


class Display:
    """a private Xvfb owned by this process; refuses a display someone else holds."""

    def __init__(self, number, log):
        self.number, self.log, self.process = number, log, None

    def __enter__(self):
        socket, lock = Path('/tmp/.X11-unix/X%d' % self.number), Path('/tmp/.X%d-lock' % self.number)
        if socket.exists() or lock.exists():
            raise Rejected('display :%d is in use; pass another --display' % self.number)
        self.output = open(self.log, 'wb')
        self.process = subprocess.Popen(['Xvfb', ':%d' % self.number, '-screen', '0', '1280x720x24', '-nolisten', 'tcp',
                                         '-noreset'], stdout=self.output, stderr=subprocess.STDOUT, start_new_session=True)
        for _ in range(100):
            if socket.exists():
                return self
            time.sleep(0.1)
        self.__exit__(None, None, None)
        raise Rejected('Xvfb :%d did not start' % self.number)

    def __exit__(self, *_):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(10)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        self.output.close()
        self.released = not Path('/tmp/.X11-unix/X%d' % self.number).exists() and not Path('/tmp/.X%d-lock' % self.number).exists()


def window_titles(display, found):
    # the os-level title of each window on the private display, while the game runs.
    def watch(process):
        env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'DISPLAY': ':%d' % display}
        while process.poll() is None:
            ids = subprocess.run(['xdotool', 'search', '--name', '.'], env=env, capture_output=True, text=True).stdout.split()
            for window in ids:
                title = subprocess.run(['xprop', '-id', window, '_NET_WM_NAME'], env=env, capture_output=True, text=True).stdout
                match = re.search(r'= "(.*)"', title)
                if match:
                    found.add(match.group(1).encode('latin-1', 'backslashreplace').decode('unicode_escape').encode('latin-1').decode('utf-8', 'replace'))
            time.sleep(1)
    return watch


# --- source -----------------------------------------------------------------------------------

def committed(path):
    return git('show', 'HEAD:./' + path)


def preflight(args):
    """everything that must hold before any file is written; Rejected names the first failure."""
    facts = {}
    status = git('status', '--porcelain', '--untracked-files=all', '--', '.').strip()
    if status:
        raise Rejected('commit the project before packaging; uncommitted or untracked:\n' + status)
    facts['commit'] = git('rev-parse', 'HEAD').strip()
    top = Path(git('rev-parse', '--show-toplevel').strip())
    facts['prefix'] = str(PROJECT.relative_to(top))
    facts['tree'] = git('rev-parse', 'HEAD:./').strip()
    project = committed('project.godot')
    scene = re.search(r'^run/main_scene="([^"]*)"', project, re.M)
    if not scene or scene.group(1) != MAIN_SCENE:
        raise Rejected('committed default scene is %s, not %s' % (scene.group(1) if scene else 'unset', MAIN_SCENE))
    facts['project_name'] = re.search(r'^config/name="([^"]*)"', project, re.M).group(1)
    version = re.search(r'^config/version="([^"]*)"', project, re.M)
    facts['project_version'] = version.group(1) if version else ''
    scene_text = committed(MAIN_SCENE.removeprefix('res://'))
    if 'path="%s"' % MAIN_SCRIPT not in scene_text or not re.search(r'^persist = true$', scene_text, re.M):
        raise Rejected('%s must run %s with persist = true' % (MAIN_SCENE, MAIN_SCRIPT))
    main = committed(MAIN_SCRIPT.removeprefix('res://'))
    build = re.search(r'^const BUILD_ID := "([^"]+)"', main, re.M)
    if not build or build.group(1) != BUILD:
        raise Rejected('committed BUILD_ID is %s, not %s' % (build.group(1) if build else 'missing', BUILD))
    save = re.search(r'^const SAVE_PATH := "([^"]+)"', main, re.M)
    if not save or save.group(1) != SAVE_PATH:
        raise Rejected('committed records file is %s, not %s' % (save.group(1) if save else 'missing', SAVE_PATH))
    if 'print("r13 overflow: build=%s; ' not in main:
        raise Rejected('the r13 startup line is missing from ' + MAIN_SCRIPT)
    presets = committed('export_presets.cfg')
    section = next((block for block in re.split(r'^(?=\[preset\.\d+\]$)', presets, flags=re.M)
                    if re.search(r'^name="%s"$' % re.escape(PRESET), block, re.M)), None)
    if section is None:
        raise Rejected('export_presets.cfg has no "%s" preset; see docs/momentum/DELIVERY.md' % PRESET)
    excluded = re.search(r'^exclude_filter="([^"]*)"', section, re.M)
    if 'platform="Linux"' not in section or not excluded or not all(p in excluded.group(1) for p in ['tests/*', 'tools/*', 'docs/*']):
        raise Rejected('"%s" must be a Linux preset excluding tests/*, tools/* and docs/*' % PRESET)
    hud = committed(EXPECT['hud_script'].removeprefix('res://'))
    controls = re.search(r'^const CONTROLS_FULL := "(.*)"$', hud, re.M)
    if not controls:
        raise Rejected('controls text not found in the hud')
    facts['controls'] = json.loads('"%s"' % controls.group(1))
    files = git('ls-tree', '-r', '--full-tree', 'HEAD:./')
    facts['files'] = [line.split('\t', 1)[1] for line in files.splitlines()]
    if not EDITOR.is_file() or digest(EDITOR) != EDITOR_SHA256:
        raise Rejected('the pinned official Godot 4.7.2 Linux editor is required at ' + str(EDITOR))
    facts['engine'] = subprocess.run([str(EDITOR), '--headless', '--version'], capture_output=True, text=True).stdout.strip()
    if not facts['engine'].startswith(ENGINE_VERSION):
        raise Rejected('engine reports %s, not %s' % (facts['engine'], ENGINE_VERSION))
    facts['templates'] = templates()
    for name, value in LICENCE_SHA256.items():
        if not (LICENCES / name).is_file() or digest(LICENCES / name) != value:
            raise Rejected('official Godot licence/notice missing or changed: ' + name)
    return facts


def templates():
    provenance = json.loads((TEMPLATES / 'PROVENANCE.json').read_text())
    if provenance.get('official_digest') != 'sha256:' + TEMPLATES_SHA256:
        raise Rejected('release templates were not extracted from the official 4.7.2 archive')
    for name in list(LINUX.values()) + list(WINDOWS.values()):
        if digest(TEMPLATES / name) != provenance['members'].get('templates/' + name):
            raise Rejected('cached release template differs from the verified archive member: ' + name)
    if (TEMPLATES / 'version.txt').read_text().strip() != '4.7.2.stable':
        raise Rejected('release templates are not 4.7.2.stable')
    return provenance


def readme(platform, facts, launch, user_dir, newline):
    lines = ['SPILLWAY R13 · OVERFLOW', 'build %s · source %s' % (BUILD, facts['commit'][:8]), '',
             *launch, '', 'Controls', *['  ' + line for line in facts['controls'].split('\n')],
             '  Esc pauses: settings, practice, restart and Quit. The pause panel shows this build.', '',
             'Records and settings: spillway_r13.cfg in ' + user_dir + '.',
             'Earlier Spillway records are never changed.', '',
             'Licences: licenses/ (Godot Engine, its third-party notices, and the CC0 textures).',
             'BUILD.json records the exact source commit, runtime and pack.']
    if platform.startswith('windows'):
        lines += ['', 'Not yet verified: running this Windows build on Windows itself. It was',
                  'packaged and checked on Linux. Please report what happens.']
    else:
        lines += ['', 'Checked on Linux with software rendering; desktop GPU pacing is not verified.']
    return newline.join(lines) + newline


def assemble(stage, pack, facts, extra):
    """the two platform folders around one pack; returns {platform: folder}."""
    folders = {}
    licence_files = {('licenses/' + name): LICENCES / name for name in LICENCE_SHA256}
    for path in facts['files']:
        # every kit's licences and asset manifest travel with the textures.
        if re.match(r'assets/[^/]+/(licences/[^/]+|MANIFEST\.json)$', path):
            kit = path.split('/')[1]
            licence_files['licenses/assets/%s/%s' % (kit, Path(path).name)] = stage / 'source' / path
    for platform, runtimes in [('linux-x86_64', LINUX), ('windows-x86_64', WINDOWS)]:
        folder = stage / 'dist' / ('%s-%s' % (NAME, platform))
        folder.mkdir(parents=True)
        for target, template in runtimes.items():
            shutil.copy2(TEMPLATES / template, folder / target)
        if platform.startswith('linux'):
            (folder / (NAME + '.x86_64')).chmod(0o755)
        shutil.copy2(pack, folder / (NAME + '.pck'))
        for target, source in licence_files.items():
            (folder / target).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, folder / target)
        if platform.startswith('linux'):
            launch = ['Start: extract the whole folder, then run ./%s.x86_64' % NAME,
                      '(or double-click it; if it will not start, run: chmod +x %s.x86_64).' % NAME,
                      'Keep %s.pck beside it. No engine or source checkout is needed.' % NAME]
            text = readme(platform, facts, launch, '~/.local/share/godot/app_userdata/%s/' % facts['project_name'], '\n')
        else:
            launch = ['Start: extract the whole folder, then double-click %s.exe.' % NAME,
                      'Windows may warn about an unknown publisher; the build is unsigned.',
                      '%s.console.exe starts the same game with a log window, for troubleshooting.' % NAME,
                      'Keep %s.pck beside the .exe files. No engine or source checkout is needed.' % NAME]
            text = readme(platform, facts, launch, '%%APPDATA%%\\Godot\\app_userdata\\%s\\' % facts['project_name'], '\r\n')
        (folder / 'README.txt').write_bytes(text.encode())
        manifest = dict(extra, platform=platform, launch=launch[0],
                        runtime_sha256={target: digest(folder / target) for target in runtimes},
                        native_windows_execution='not verified' if platform.startswith('windows') else 'not applicable')
        (folder / 'BUILD.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
        folders[platform] = folder
    return folders


def archive(folder, destination):
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for path in sorted(folder.rglob('*')):
            if path.is_file():
                output.write(path, Path(folder.name) / path.relative_to(folder))


def publish(dist, facts):
    zips = []
    for folder in sorted(p for p in dist.iterdir() if p.is_dir()):
        destination = dist / ('%s-%s-%s.zip' % (BUILD, folder.name.removeprefix(NAME + '-'), facts['commit'][:8]))
        archive(folder, destination)
        zips.append(destination)
    (dist / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (digest(z), z.name) for z in zips))
    return zips


def package(args):
    output = args.output.expanduser().resolve()
    top = Path(git('rev-parse', '--show-toplevel').strip())
    if output == top or top in output.parents:
        raise Rejected('delivery output must be outside the Git checkout')
    if output.exists() and any(output.iterdir()):
        raise Rejected('output %s already has files; packages are never overwritten' % output)
    if not args.startup_only and args.tape is None:
        raise Rejected('pass --tape for a packed play proof, or --startup-only to ship without one')
    facts = preflight(args)
    output.mkdir(parents=True, exist_ok=True)
    evidence = output / 'evidence'
    stage = output / '.stage'
    evidence.mkdir()
    stage.mkdir()
    try:
        # freeze: exactly the committed tree, never the working checkout or its import cache.
        tar = stage / 'source.tar'
        # from a subdirectory, archive also filters by that directory; run it from the top.
        tar.write_bytes(git('archive', '--format=tar', 'HEAD:' + facts['prefix'], binary=True, cwd=PROJECT.parents[len(Path(facts['prefix']).parts) - 1]))
        facts['archive_sha256'] = digest(tar)
        with tarfile.open(tar) as frozen:
            frozen.extractall(stage / 'source', filter='data')
        tar.unlink()
        source = stage / 'source'
        listed = sorted(str(p.relative_to(source)) for p in source.rglob('*') if p.is_file() or p.is_symlink())
        if listed != sorted(facts['files']):
            raise Rejected('git archive output differs from the committed file list')
        (evidence / 'source-sha256.txt').write_text(''.join('%s  %s\n' % (digest(source / p), p) for p in listed))
        env = engine_env(stage / 'profile')
        checked([EDITOR, '--headless', '--path', source, '--import'], source, env, evidence / 'import.log')
        pack = stage / 'pack' / (NAME + '.pck')
        pack.parent.mkdir()
        checked([EDITOR, '--headless', '--path', source, '--export-pack', PRESET, pack], source, env, evidence / 'export.log')
        startup = checked([EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', source, '--', '--verify-startup'],
                          source, env, evidence / 'source-startup.log', 120)
        line = STARTUP.search(startup)
        if not line or line['build'] != BUILD:
            raise Rejected('source startup did not print the r13 identity')
        facts['startup'] = line.group(0)
        facts['course_key'] = line['key']
        if int(line['stages']) != len(args.stages):
            raise Rejected('the course has %s stages; --stages names %d' % (line['stages'], len(args.stages)))
        reference = None
        if args.tape is not None:
            reference = source_reference(args.tape.expanduser().resolve(), source, evidence)
        helpers = {p: digest(source / p) for p in ['tools/package-overflow.py', 'tools/check-overflow-pack.sh',
                                                   'tools/overflow-pack-probe.gd', 'tools/momentum-tape.py', 'tools/momentum-tape.gd']
                   if (source / p).is_file()}
        extra = {'game': 'Spillway', 'course': 'Overflow', 'build': BUILD, 'project_version': facts['project_version'],
                 'source_commit': facts['commit'], 'source_tree': facts['tree'], 'source_project_path': facts['prefix'],
                 'source_archive_sha256': facts['archive_sha256'], 'source_files': len(listed),
                 'engine': facts['engine'], 'export_editor_sha256': EDITOR_SHA256, 'export_preset': PRESET,
                 'runtime': {'kind': 'official Godot 4.7.2 release export templates', 'archive': facts['templates']['archive_url'],
                             'archive_sha256': TEMPLATES_SHA256},
                 'pack_sha256': digest(pack), 'main_scene': MAIN_SCENE, 'records_file': SAVE_PATH,
                 'user_data_folder': facts['project_name'], 'course_key': facts['course_key'], 'stages': args.stages,
                 'startup_line': facts['startup'], 'helpers_sha256': helpers,
                 'helpers_committed': digest(Path(__file__)) == helpers.get('tools/package-overflow.py'),
                 'verification': 'VERIFICATION.json beside the zips'}
        folders = assemble(stage, pack, facts, extra)
        zips = publish(stage / 'dist', facts)
        result = check_package(stage / 'dist', args, evidence / 'check', facts['course_key'], reference, pack_expect=digest(pack))
        destination = output if result['ok'] else output / 'rejected'
        destination.mkdir(exist_ok=True)
        for path in zips + [stage / 'dist' / 'SHA256SUMS']:
            shutil.move(str(path), destination / path.name)
        build = dict(extra, platforms=[z.name for z in zips])
        (destination / 'BUILD.json').write_text(json.dumps(build, indent=2, ensure_ascii=False) + '\n')
        (destination / 'VERIFICATION.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
        for platform in folders:
            print(destination / ('%s-%s-%s.zip' % (BUILD, platform, facts['commit'][:8])))
        if not result['ok']:
            raise Rejected('packed checks failed; zips kept under %s, see VERIFICATION.json' % destination)
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def source_reference(tape, source, evidence):
    """expand the tape and play it in source mode on the frozen copy: the tick-for-tick reference."""
    expanded = evidence / 'tape.expanded.json'
    result = subprocess.run([sys.executable, '-I', source / 'tools/momentum-tape.py', 'expand', tape], capture_output=True, text=True)
    if result.returncode:
        raise Rejected('tape does not expand: ' + result.stderr)
    expanded.write_text(result.stdout)
    run = evidence / 'source-tape'
    result = subprocess.run([sys.executable, '-I', source / 'tools/momentum-tape.py', 'run', expanded, '--out', run,
                             '--game-script', MAIN_SCRIPT, '--game-class', '', '--headless', '--wall-budget', '400'],
                            capture_output=True, text=True, env=dict(os.environ, GODOT=str(EDITOR)))
    (evidence / 'source-tape.log').write_text(result.stdout + result.stderr)
    rows = [json.loads(line) for line in (run / 'evaluator/trace.jsonl').read_text().splitlines() if '"phase":"tape"' in line]
    last = rows[-1]['game'] if rows else {}
    if result.returncode or not last.get('finished') or last.get('finish_kind') != 'clean' or last.get('respawns'):
        raise Rejected('the tape does not finish clean in source mode on this commit: %s' % last)
    return {'tape': str(expanded), 'trace': str(run / 'evaluator/trace.jsonl'), 'arm_motor_steps': rows[0]['pre']['tape_step_count'],
            'source_finish': last, 'tape_sha256': digest(tape)}


# --- check ------------------------------------------------------------------------------------

def extract(path, target):
    # like unzip and desktop extractors, restore the stored unix modes (the runtime's exec bit).
    with zipfile.ZipFile(path) as archive_file:
        for info in archive_file.infolist():
            written = Path(archive_file.extract(info, target))
            mode = info.external_attr >> 16 & 0o777
            if mode and not info.is_dir():
                written.chmod(mode)


def check_package(dist, args, evidence, course_key=None, reference=None, pack_expect=None):
    evidence.mkdir(parents=True, exist_ok=True)
    checks = []

    def record(name, ok, detail=''):
        checks.append({'name': name, 'ok': bool(ok), 'detail': detail})
        print('%s %s%s' % ('PASS' if ok else 'FAIL', name, '' if detail in ('', None) else ' (%s)' % detail))
        return ok

    sums = dict(reversed(line.split('  ', 1)) for line in (dist / 'SHA256SUMS').read_text().splitlines())
    zips = sorted(dist.glob(BUILD + '-*.zip'))
    record('SHA256SUMS lists exactly the zips', sorted(sums) == [z.name for z in zips] and len(zips) == 2, sorted(sums))
    record('zip checksums match', all(digest(z) == sums.get(z.name) for z in zips))
    provenance = templates()
    extracted = {}
    for z in zips:
        platform = 'linux-x86_64' if '-linux-' in z.name else 'windows-x86_64'
        target = evidence / ('extract-' + platform)
        shutil.rmtree(target, ignore_errors=True)
        extract(z, target)
        folder = target / ('%s-%s' % (NAME, platform))
        runtimes = LINUX if platform.startswith('linux') else WINDOWS
        found = sorted(str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file())
        expected = sorted([*runtimes, NAME + '.pck', 'README.txt', 'BUILD.json'] + [n for n in found if n.startswith('licenses/')])
        (evidence / ('files-%s.txt' % platform)).write_text(''.join('%s  %s\n' % (digest(folder / n), n) for n in found))
        record(platform + ': nothing but runtime, pack, readme, manifest and licences', folder.is_dir() and found == expected and
               len([n for n in found if n.startswith('licenses/')]) >= 3, sorted(set(found) - set(expected)))
        record(platform + ': runtime is the official release template', all(
            (folder / t).is_file() and digest(folder / t) == provenance['members']['templates/' + s] for t, s in runtimes.items()))
        manifest = json.loads((folder / 'BUILD.json').read_text()) if (folder / 'BUILD.json').is_file() else {}
        pack_sha = digest(folder / (NAME + '.pck')) if (folder / (NAME + '.pck')).is_file() else ''
        record(platform + ': manifest names this pack and build', manifest.get('pack_sha256') == pack_sha and manifest.get('build') == BUILD
               and (pack_expect is None or pack_sha == pack_expect), pack_sha)
        notes = (folder / 'README.txt').read_bytes() if (folder / 'README.txt').is_file() else b''
        record(platform + ': readme names the build and launch', BUILD.encode() in notes and (b'\r\n' in notes) == platform.startswith('windows'))
        extracted[platform] = (folder, pack_sha)
    if len(extracted) == 2:
        record('both platforms carry the same pack', extracted['linux-x86_64'][1] == extracted['windows-x86_64'][1])
    static_ok = all(c['ok'] for c in checks)
    runs = {}
    try:
        if static_ok and 'linux-x86_64' in extracted:
            runs = check_runs(extracted['linux-x86_64'], args, evidence, course_key, reference, record)
    finally:
        # the bulky runtimes stay in the zips; the evidence keeps their hashes.
        for platform in extracted:
            shutil.rmtree(evidence / ('extract-' + platform), ignore_errors=True)
        shutil.rmtree(evidence / 'runs/harness', ignore_errors=True)
    ok = all(c['ok'] for c in checks)
    result = {'ok': ok, 'build': BUILD, 'checks': checks, 'runs': runs, 'stages': args.stages,
              'scope': 'Linux release runtime from the zip, private Xvfb, llvmpipe, Dummy audio, isolated XDG; '
                       'engine-injected key and relative-mouse events; Windows static only',
              'windows_native_execution': 'not verified: zip contents and runtime hashes only',
              'probe_sha256': digest(PROBE), 'tool_sha256': digest(Path(__file__))}
    if not static_ok:
        result['runs'] = 'skipped: static checks failed'
    (evidence / 'summary.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    return result


def spec_for(mode, folder, out, args, course_key, reference, extra):
    expect = dict(EXPECT, stages=args.stages, pack_sha256=digest(folder / (NAME + '.pck')),
                  pack_required=args.pack_required, loaded_required=LOADED + args.require, **extra)
    if course_key:
        expect['course_key'] = course_key
    spec = {'mode': mode, 'out': str(out), 'pack': str(folder / (NAME + '.pck')), 'expect': expect,
            'settle_frames': 45, 'capture_ticks': [0, 600, 1200, 1800, 2400]}
    if mode == 'play':
        spec.update(tape=reference['tape'], arm_motor_steps=reference['arm_motor_steps'],
                    reference_trace=reference.get('trace', ''), reference_tolerance_m=0.0)
    return spec


def check_runs(extracted, args, evidence, course_key, reference, record):
    folder, _ = extracted
    runs = {}
    # 1. a player's launch path: the shipped binary finds its pack, from an empty directory.
    cwd = evidence / 'runs/startup-headless/cwd'
    cwd.mkdir(parents=True)
    profile = evidence / 'runs/startup-headless/profile'
    code, text = run_engine([folder / (NAME + '.x86_64'), '--headless', '--audio-driver', 'Dummy', '--', '--verify-startup'],
                            cwd, engine_env(profile), evidence / 'runs/startup-headless/engine.log', 120)
    line = STARTUP.search(text)
    runs['startup_headless'] = {'exit': code, 'line': line.group(0) if line else None}
    record('shipped binary starts the r13 scene from its own pack', code == 0 and line and line['build'] == BUILD
           and line['course'] == 'Overflow' and int(line['stages']) == len(args.stages) and line['runner'] == EXPECT['runner_policy']
           and line['renderer'] == 'gl_compatibility' and line['records'] == 'off' and (course_key is None or line['key'] == course_key),
           line.group(0) if line else 'no startup line')
    record('headless startup is error-free', not ERRORS.search(text))
    record('headless startup writes no records', not [p for p in profile_files(profile) if p.endswith('.cfg')])
    record('working directory stays empty', not any(cwd.iterdir()))
    # 2. native runs through a harness copy: the same bytes plus an override.cfg naming the probe.
    harness = evidence / 'runs/harness'
    harness.mkdir()
    for name in [NAME + '.x86_64', NAME + '.pck']:
        shutil.copy2(folder / name, harness / name)
    (harness / 'override.cfg').write_text('[autoload]\nPackProbe="*%s"\n' % PROBE)
    same = all(digest(harness / n) == digest(folder / n) for n in [NAME + '.x86_64', NAME + '.pck'])
    record('harness runtime and pack are byte-identical to the zip', same)
    profile = evidence / 'runs/profile'
    modes = ['startup'] if args.tape is None and reference is None else ['play', 'reload']
    if reference is None and args.tape is not None:
        reference = {'tape': str(args.tape.resolve()), 'arm_motor_steps': args.arm_motor_steps,
                     'trace': str(args.reference.resolve()) if args.reference else ''}
    best = None
    with Display(args.display, evidence / 'runs/xvfb.log') as display:
        for mode in modes:
            out = evidence / 'runs' / mode
            (out / 'cwd').mkdir(parents=True)
            extra = {'profile_state': 'new', 'fresh_profile': True} if mode != 'reload' else {'profile_state': 'loaded', 'best_time': best}
            spec = spec_for(mode, harness, out, args, course_key, reference, extra)
            (out / 'spec.json').write_text(json.dumps(spec, indent=2, ensure_ascii=False))
            titles = set()
            before = profile_files(profile)
            code, text = run_engine([harness / (NAME + '.x86_64'), '--display-driver', 'x11', '--audio-driver', 'Dummy',
                                     '--fixed-fps', '30', '--', '--pack-probe=%s' % (out / 'spec.json')],
                                    out / 'cwd', engine_env(profile, args.display), out / 'engine.log', args.deadline,
                                    window_titles(args.display, titles))
            report = json.loads((out / 'probe.json').read_text()) if (out / 'probe.json').is_file() else {}
            after = profile_files(profile)
            runs[mode] = {'exit': code, 'failures': report.get('failures'), 'titles': sorted(titles), 'frames': report.get('frames'),
                          'run': report.get('run'), 'pause': report.get('pause'), 'reference': report.get('reference'),
                          'profile_after': after}
            record(mode + ': probe ran and found no failures', report.get('failures') == 0,
                   [c['name'] for c in report.get('checks', []) if not c['ok']] or report.get('abort'))
            record(mode + ': Quit on the pause panel ended the game', code == 0, code)
            record(mode + ': engine log is error-free', not ERRORS.search(text), ERRORS.findall(text)[:3])
            record(mode + ': os window title', TITLE in titles, sorted(titles))
            record(mode + ': working directory stays empty', not any((out / 'cwd').iterdir()))
            records = [Path(p).name for p in after if p.endswith('.cfg')]
            if mode == 'play':
                best = (report.get('run') or {}).get('elapsed')
                record('play: only the r13 records file was written', records == [SAVE_PATH.removeprefix('user://')], records)
            if mode == 'reload':
                record('reload: the profile is read, not rewritten', after == before, '')
            if mode == 'startup':
                record('startup: no records file before a finish', records == [], records)
    runs['display_released'] = display.released
    record('private display released', display.released)
    leftovers = [pid for pid in os.listdir('/proc') if pid.isdigit() and str(evidence / 'runs').encode() in _cmdline(pid)]
    record('no owned engine process remains', not leftovers, leftovers)
    return runs


def _cmdline(pid):
    try:
        return Path('/proc/%s/cmdline' % pid).read_bytes()
    except OSError:
        return b''


def profile_files(profile):
    # files the game itself wrote under app_userdata, without godot's logs and shader cache.
    root = profile / 'data/godot/app_userdata'
    return {str(p.relative_to(root)): digest(p) for p in sorted(root.rglob('*')) if root.exists()
            and p.is_file() and 'shader_cache' not in p.parts and 'logs' not in p.parts}


def pack_required(files):
    # committed game resources, as res:// paths; the probe looks each up inside the pack.
    return ['res://' + p for p in files if p.startswith(SHIPPED_DIRS) and p.endswith(SHIPPED_EXT)
            and not p.endswith('MANIFEST.json')]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ['package', 'check']:
        p = sub.add_parser(name)
        p.add_argument('--stages', required=True, type=lambda s: [t.strip() for t in s.split(',')],
                       help='expected segment titles in order, finish last, e.g. "Pier,Chute,Tail race,Finish"')
        p.add_argument('--tape', type=Path, help='a key/mouse tape that finishes this course clean')
        p.add_argument('--require', action='append', default=[], help='a res:// module the running game must load (repeatable)')
        p.add_argument('--display', type=int, default=167, help='private Xvfb display number')
        p.add_argument('--deadline', type=float, default=900, help='per native run, seconds')
    package_parser, check_parser = sub.choices['package'], sub.choices['check']
    package_parser.add_argument('--output', type=Path, required=True, help='a new or empty directory outside Git')
    package_parser.add_argument('--startup-only', action='store_true', help='no packed play proof; says so in VERIFICATION.json')
    check_parser.add_argument('package_dir', type=Path, help='a directory holding the zips and SHA256SUMS')
    check_parser.add_argument('--evidence', type=Path, required=True, help='a new directory for logs and frames')
    check_parser.add_argument('--reference', type=Path, help='source-mode executor trace.jsonl of the same tape')
    check_parser.add_argument('--arm-motor-steps', type=int, default=10, help="the reference's motor steps before tick 0")
    check_parser.add_argument('--course-key', help='expected course key from a source startup')
    args = parser.parse_args()
    try:
        if args.command == 'package':
            files = git('ls-tree', '-r', '--name-only', '--full-tree', 'HEAD:./').split('\n')
            args.pack_required = sorted(set(pack_required(files)) | set(args.require))
            package(args)
        else:
            evidence = args.evidence.expanduser().resolve()
            if evidence.exists() and any(evidence.iterdir()):
                raise Rejected('evidence directory %s already has files' % evidence)
            # the resources a package must hold come from its own source commit, not this checkout.
            build = json.loads((args.package_dir / 'BUILD.json').read_text())
            files = git('ls-tree', '-r', '--name-only', '--full-tree', build['source_commit'] + ':' + build['source_project_path']).split('\n')
            args.pack_required = sorted(set(pack_required(files)) | set(args.require))
            if args.tape is not None and args.tape.read_text().find('"expanded": true') < 0:
                raise Rejected('check takes an expanded tape: python3 tools/momentum-tape.py expand TAPE > FILE')
            result = check_package(args.package_dir.resolve(), args, evidence, args.course_key)
            sys.exit(0 if result['ok'] else 1)
    except Rejected as error:
        print('package-overflow: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
