#!/usr/bin/env python3
"""compare every delivered R19 file, allowing only explicitly hashed R20 presentation/scoring edits."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

BASELINE = "065f7b27993df7ae2511eb34eb665d271dded13c"
ALLOWED = frozenset({"project.godot", "scripts/r16_style.gd", "scripts/r16_style_panel.gd",
                     "scripts/r18_style_panel.gd", "scripts/r19_ghost_share.gd"})


def archive_manifest(repo: Path, commit: str) -> dict[str, str]:
    process = subprocess.Popen(["git", "archive", commit + ":projects/foldrunner"], cwd=repo,
                               stdout=subprocess.PIPE)
    result = {}
    with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
        for entry in archive:
            if entry.isfile():
                result[entry.name] = hashlib.file_digest(archive.extractfile(entry), "sha256").hexdigest()
            elif not entry.isdir():
                raise ValueError("unsupported source archive entry: " + entry.name)
    if process.wait() != 0:
        raise ValueError("git archive failed")
    return result


def compare(baseline: dict[str, str], candidate: dict[str, str], intentional: dict[str, str]) -> dict:
    errors = []
    changed = {name: candidate.get(name) for name, digest in baseline.items()
               if candidate.get(name) != digest}
    for name, digest in changed.items():
        if digest is None:
            errors.append("delivered file deleted: " + name)
        elif name not in ALLOWED:
            errors.append("protected delivered file changed: " + name)
        elif intentional.get(name) != digest:
            errors.append("changed file lacks exact reviewed hash: " + name)
    for name, digest in intentional.items():
        if name not in ALLOWED or name not in changed or changed.get(name) != digest:
            errors.append("unknown, stale or incorrect intentional change: " + name)
    return {"ok": not errors, "errors": errors, "baseline_files": len(baseline),
            "changed_old_files": changed, "new_files": sorted(set(candidate) - set(baseline)),
            "scope": "all committed R19 project files; no original map or movement edit is allowed"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", default="HEAD")
    parser.add_argument("--intentional", type=Path, help="JSON mapping of approved changed path to exact SHA256")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    commit = subprocess.check_output(["git", "rev-parse", args.candidate], cwd=repo, text=True).strip()
    intentional = json.loads(args.intentional.read_text()) if args.intentional else {}
    if not isinstance(intentional, dict) or not all(isinstance(k, str) and isinstance(v, str)
                                                  for k, v in intentional.items()):
        parser.error("intentional must map path strings to exact SHA256 strings")
    result = compare(archive_manifest(repo, BASELINE), archive_manifest(repo, commit), intentional)
    result.update(baseline_commit=BASELINE, candidate_commit=commit,
                  helper_sha256=hashlib.file_digest(Path(__file__).open("rb"), "sha256").hexdigest())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ["ok", "baseline_files", "changed_old_files", "errors"]}))
    raise SystemExit(0 if result["ok"] else 1)


if __name__ == "__main__":
    main()
