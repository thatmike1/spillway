# FLOW corrections after the independent challenge

Root fixes, 7 November 2026. FLOW is still an experimental policy. R12's player, main,
geometry, packages and records remain unchanged. These corrections make the comparison
credible; they do not establish a preferred motor or human satisfaction.

- **Mouse delivery:** unconsumed view turn now has a 67 ms P lifetime, spent as the heading
  catches up. Grounding, no input, braking, wrong-side input and reversals clear it. The
  same 0.9 radian sweep earns 0.9 m/s at 30, 60 and 120 events/s. Six additional causal
  sampling-phase cases also agree within 0.000001 m/s. Paths differ slightly because the
  input samples arrive at different times; no claim of identical trajectories is made.
- **Landing:** both the caught fall and current post-collision velocity are constrained
  against the complete active contact cone. A floor projection can no longer restore
  motion into the wall in the seeded isolations or the input-earned reproduction. The
  final trace checker rejects velocity into active walls and verifies actual displacement
  against the engine's real velocity.
- **Crests:** first preserving the previous support's history activated the advertised
  rule, but produced two and three unrequested launches on the small-step fixtures. That
  trial is retained as `after-1/`. Root removed automatic continuous-crest launches rather
  than tune another hidden threshold. Actual ramp edges and jump slope carry remain.

Evidence is under outer `checkpoints/spillway/r13/controller-review-sol/root-fix/`:
`before/`, `after-1/`, `after-2/`, `after-final/`, their logs, and `fixed-check.json`.
The original review probe is committed at 78ebc51b; the extended version adds six delivery
phase cases. The checker is root's analysis of the post-physics traces, not a motor-emitted
certificate. `before-check.json` intentionally fails on the old faults and missing new
phase cases. `fixed-check.json` passes on all 67 characterization episodes. The original
lab probe also remains 38/38 in `original-probe.log`. Import/parse logs are retained.

Reproduce from the project with the pinned binary used by tools/check-spillway.sh:

```sh
$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --fixed-fps 120 --path . --script res://tests/momentum_review_probe.gd -- \
  --out=/tmp/spillway-momentum-review
python3 tools/check-momentum-review.py /tmp/spillway-momentum-review
```

This is controlled injected-input/headless evidence. Physical mouse timing, native display
latency, a full playable route and subjective feel remain separate questions. A/D's lack
of fixed-view lateral correction is an intentional FLOW tradeoff, still open to comparison.
