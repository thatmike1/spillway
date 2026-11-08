# Exact R14 records

P serialization decision, 8 November 2026. Record times are ranked and saved as integer
physics ticks at the active preset's rate. This changes neither movement nor the running
clock, finish detection, splits, record keys or eligibility.

Godot 4.7.2 ConfigFile writes some exactly representable times with fewer digits. The
seeded serialization reproduction saved 45.8203125 s as 45.820313 s. Reloading that best
made an identical run compare faster. This was a real save/load error, not a measured
extra gain or a difference between Source presets.

Each course section now has `time_ticks_version=1`, `clean_best_ticks`, `open_best_ticks`,
`clean_split_ticks` and `clean_segment_ticks`. Together with `physics_hz`, these are the
authoritative record values. Existing floating-point fields remain readable summaries;
their text can still be rounded. Profile format stays 1 because this is an additive
encoding within the existing isolated R14 namespace.

The game converts elapsed times to their nearest whole physics tick for record ranking.
Equal tick counts do not set a new best, including at R13's 120 Hz where accumulating
1/120 has small floating-point error. One tick faster still wins. Clean splits belong to
the best complete run; best segments remain independent per-segment records.

Older R14 sections without the encoding marker are recovered to the nearest tick at
their own key's rate. A section with the marker but an invalid version, rate, integer
payload, split order or array length is rejected. It cannot silently use the rounded
summaries instead. R12 and R13 profiles are never read or written.

`tests/test_r14_record_precision.gd` covers seeded save/load at 64, 120 and 128 Hz,
all split and segment values, equal/sub-tick/faster comparisons, damaged payloads and
legacy float recovery. Separate fresh processes also play the labelled loop fixture
twice with W and check exact restored records, equal finish times, no false new-best
message and an unchanged profile. These are input-driven fixture runs, not course or
human play evidence.

The first test attempt had two incorrect expected segment values at 120 Hz because the
test itself subtracted floating-point split times. The production values were correct
integer-tick differences. That trial is retained separately; expected segments now come
from their independent integer differences.

Run from `projects/foldrunner` with the pinned Godot executable:

```sh
~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/test_r14_record_precision.gd -- --out=OUTSIDE_CHECKOUT
```

Evidence: outer `checkpoints/spillway/r14/record-precision/` and the original
`record-precision-before/` serialization diagnostic. Final packed checks must verify
the integer payload and its restored seconds, rather than allow float-format loss.

The independent follow-up found a damaged String version marker could log a script error.
Types are now checked first, unsupported tick magnitudes are rejected, and the expanded
precision suite passes 66/66. The independent 46 ranking/save-load assertions pass without
script errors. See [RECORD-DISPLAY-REVIEW.md](RECORD-DISPLAY-REVIEW.md) for red/green evidence.
