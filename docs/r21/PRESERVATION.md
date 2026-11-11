# R21 committed-source preservation

The comparison baseline is commit `e6baa995da84d380abc8b8d6a3769b33e771945e`, subtree `projects/foldrunner`. Every committed R20 project file is protected from deletion and byte or executable-mode changes. This includes the original maps and overlays, Source motor and F2 presets, style and backwards-stack rules, Through Line, Classic, Pendulum and R20 Elastic. Saltglass and Tether changes belong in new R21 modules. New files are allowed; the gate does not establish their behavior or prove that wiring uses them correctly.

Only `project.godot` and `scripts/r19_ghost_share.gd` may change, and only with the parent’s review and the exact SHA256 of the resulting file. The former is for R21 scene/version wiring; the latter is reserved for build label or portable format identity if needed. Hash approval is a byte-level gate, not a semantic review. Deletions, mode changes, unknown entries, duplicate keys, wrong hashes and stale approvals fail. No scorer or original-map exception exists.

Run from any directory, using the tool from this checkout and an exact 40-character candidate commit:

```sh
python3 projects/foldrunner/tools/check-r21-preservation.py --candidate FULL_COMMIT_ID --out /tmp/r21-preservation.json
```

For reviewed changes, add `--intentional /path/to/reviewed-hashes.json`, a JSON object such as `{"project.godot": "<64 lowercase hex digits>"}`. Omit it when nothing is approved. This input records hashes, not who reviewed them; the parent must establish that provenance and check the permitted semantics separately.

The helper reads both commits through Git, from the fixed project subtree. It hashes the streamed Git archive and each regular file, verifies archive content and membership against the committed Git tree and blob IDs, and refuses unsupported entries or archive filtering/substitution. It ignores the working tree, including dirty and untracked files. It compares all baseline files and reports added files. A successful self-comparison is a preparation check, not acceptance of a later candidate. Final acceptance must run against the exact final candidate commit, with reviewed exceptions, and separately verify behavior, runtime, packaging and any dirty working tree.

The outer `look/evidence/r21-baseline/` inventory and source receipt record the baseline archive, source tree and selected critical paths. They are evidence, not a substitute for rerunning the gate against the final commit.
