# The R15 comparison stays frozen

`tools/check-r16-preservation.py` compares every delivered script, shader, scene and asset with Git commit `8a254d16455d69cee6df8ca37f82c53d04e6ab4c`. Missing files, changed bytes and symlink substitutions fail. R16 adds separate modules and overlays. The existing project settings and export presets stay unchanged except the new default scene, round version and appended export preset.

Run from the project:

```sh
python3 -I tools/check-r16-preservation.py --out OUT.json --r15-delivery /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r15
python3 -I tests/test_r16_preservation.py --out CONTROLS.json
```

Before R16 becomes the default, `--allow-r15-default` produces an explicitly labelled development diagnostic. Release checks must omit it. `--project DIR` checks an external frozen snapshot against the same pinned Git source.

This proves source and optional download preservation. It does not prove that additional R16 geometry or observers leave movement unchanged. Those require same-input course traces with and without the new modules, plus checks of the built geometry and profiles. The old R15 ZIPs remain the playable comparison.
