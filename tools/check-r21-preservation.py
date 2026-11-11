#!/usr/bin/env python3
"""compare committed project blobs against the immutable r20 archive."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tarfile

BASELINE = 'e6baa995da84d380abc8b8d6a3769b33e771945e'
SUBTREE = 'projects/foldrunner'
ALLOWED = {'project.godot', 'scripts/r19_ghost_share.gd'}
HEX40 = re.compile(r'[0-9a-f]{40}\Z')
HEX64 = re.compile(r'[0-9a-f]{64}\Z')
REPO = Path(__file__).resolve().parents[3]


def git(*args):
    root = subprocess.check_output(['git', '-C', str(REPO), 'rev-parse', '--show-toplevel']).decode().strip()
    return subprocess.check_output(['git', '-C', root, *args])


class HashReader:
    def __init__(self, stream):
        self.stream = stream
        self.digest = hashlib.sha256()

    def read(self, size=-1):
        data = self.stream.read(size)
        self.digest.update(data)
        return data


def inventory(commit):
    if not HEX40.fullmatch(commit):
        raise ValueError('commit must be an exact lowercase 40-character object id')
    if git('cat-file', '-t', commit).strip() != b'commit':
        raise ValueError('object is not a commit')
    tree = git('rev-parse', commit + ':' + SUBTREE).decode().strip()
    entries = {}
    for row in git('ls-tree', '-rz', '--full-tree', commit, '--', SUBTREE).split(b'\0'):
        if not row:
            continue
        meta, raw_path = row.split(b'\t', 1)
        mode, kind, oid = meta.decode('ascii').split()
        path = raw_path.decode('utf-8')
        prefix = SUBTREE + '/'
        if not path.startswith(prefix) or kind != 'blob' or mode not in ('100644', '100755'):
            raise ValueError('unsupported committed entry: ' + path)
        entries[path[len(prefix):]] = (mode, oid)
    if not entries:
        raise ValueError('empty project tree')
    root = git('rev-parse', '--show-toplevel').decode().strip()
    process = subprocess.Popen(['git', '-C', root, 'archive', '--format=tar', commit + ':' + SUBTREE], stdout=subprocess.PIPE)
    reader = HashReader(process.stdout)
    files = {}
    try:
        with tarfile.open(fileobj=reader, mode='r|') as archive:
            for item in archive:
                if item.isdir():
                    continue
                if not item.isfile() or item.name not in entries or item.name in files:
                    raise ValueError('unsupported, unknown or duplicate archive entry: ' + item.name)
                mode, oid = entries[item.name]
                if bool(item.mode & 0o111) != (mode == '100755'):
                    raise ValueError('archive mode differs from tree: ' + item.name)
                sha256 = hashlib.sha256()
                blob = hashlib.sha1(('blob %d\0' % item.size).encode())
                stream = archive.extractfile(item)
                while True:
                    chunk = stream.read(1024 * 1024)
                    if not chunk:
                        break
                    sha256.update(chunk)
                    blob.update(chunk)
                if blob.hexdigest() != oid:
                    raise ValueError('archive content differs from committed blob: ' + item.name)
                files[item.name] = {'sha256': sha256.hexdigest(), 'mode': mode}
        while reader.read(1024 * 1024):
            pass
    finally:
        process.stdout.close()
        status = process.wait()
    if status or set(files) != set(entries):
        raise ValueError('archive failed or omitted committed project entries')
    return {'commit': commit, 'tree': tree, 'archive_sha256': reader.digest.hexdigest(),
            'files': dict(sorted(files.items()))}


def compare(baseline, candidate, approved):
    if not isinstance(approved, dict) or any(not isinstance(k, str) or not isinstance(v, str) or not HEX64.fullmatch(v) for k, v in approved.items()):
        raise ValueError('exceptions must map paths to lowercase SHA256 hashes')
    errors = []
    changed = {name: candidate.get(name) for name, entry in baseline.items() if candidate.get(name) != entry}
    for name, entry in changed.items():
        if entry is None:
            errors.append('deleted: ' + name)
        elif name not in ALLOWED:
            errors.append('protected file changed: ' + name)
        elif entry['mode'] != baseline[name]['mode'] or approved.get(name) != entry['sha256']:
            errors.append('missing exact approval or mode changed: ' + name)
    for name, digest in approved.items():
        if name not in ALLOWED or name not in changed or changed[name] is None or changed[name]['sha256'] != digest or changed[name]['mode'] != baseline[name]['mode']:
            errors.append('unknown, stale or incorrect exception: ' + name)
    return {'ok': not errors, 'errors': errors, 'baseline_files': len(baseline),
            'changed_old_files': changed, 'new_files': sorted(candidate.keys() - baseline.keys())}



def settings(data):
    result = {}
    section = ''
    for raw in data.decode('utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith((';', '#')):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1]
        elif '=' in line:
            key, value = line.split('=', 1)
            name = section + '/' + key.strip()
            if name in result:
                raise ValueError('duplicate project setting: ' + name)
            result[name] = value.strip()
        else:
            raise ValueError('unrecognized project setting: ' + line)
    return result


def project_settings_preserved(old, new):
    allowed = {'application/config/version', 'application/run/main_scene'}
    return {k: v for k, v in settings(old).items() if k not in allowed} == {
        k: v for k, v in settings(new).items() if k not in allowed}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--candidate', required=True, help='exact 40-character commit id')
    p.add_argument('--intentional', type=Path, help='parent-reviewed JSON path-to-SHA256 mapping')
    p.add_argument('--out', required=True, type=Path)
    args = p.parse_args()
    try:
        approved = json.loads(args.intentional.read_text(), object_pairs_hook=unique_object) if args.intentional else {}
        old = inventory(BASELINE)
        new = inventory(args.candidate)
        result = compare(old['files'], new['files'], approved)
        if 'project.godot' in result['changed_old_files'] and result['changed_old_files']['project.godot'] is not None:
            before = git('show', BASELINE + ':' + SUBTREE + '/project.godot')
            after = git('show', args.candidate + ':' + SUBTREE + '/project.godot')
            if not project_settings_preserved(before, after):
                result['errors'].append('project.godot changes settings beyond scene/version wiring')
                result['ok'] = False
        result.update(baseline_commit=BASELINE, baseline_tree=old['tree'], baseline_archive_sha256=old['archive_sha256'], candidate_commit=args.candidate, candidate_tree=new['tree'], candidate_archive_sha256=new['archive_sha256'])
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({k: result[k] for k in ('ok', 'baseline_files', 'errors')}))
        return int(not result['ok'])
    except (ValueError, OSError, subprocess.CalledProcessError, tarfile.TarError) as error:
        p.exit(2, 'preservation unavailable: %s\n' % error)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate exception key: ' + key)
        result[key] = value
    return result


if __name__ == '__main__':
    raise SystemExit(main())
