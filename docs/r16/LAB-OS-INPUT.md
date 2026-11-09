# R16 lab chain through OS keys

The exact shipped Linux pack also passes a focused synthetic OS-keyboard challenge: normal-spawn running bhops, descent Shift with Space held, landing slide, a fresh hop out, then two A/D-held wall kicks from authored chamber practice. The driver uses XTest through `xdotool`; a read-only autoload observes state and takes player-camera images. It never writes position, velocity, input, progress or mechanics. This is a coordinate-aware test controller, not human play or physical-input latency evidence.

Run from `projects/foldrunner`, with a new output directory:

```sh
python3 -I -B tests/r16_lab_os_chain.py \
  --candidate /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r16 \
  --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/lab-os-final/new-attempt
```

The driver extracts the unchanged ZIP into RAM, verifies the official runtime and pack, adds only its external observation autoload and uses an empty working directory. No fixed-FPS flag is supplied. The test uses real OS keys for movement, Esc, the checkpoint picker and Quit. The controller reads live coordinates and counters, so it proves input delivery and resulting movement rather than unaided timing or route discovery. It starts the slide challenge at the ordinary lab spawn and selects the authored Wall chamber through the actual menu, explicitly as practice.

## Successful third attempt

Outer evidence: `checkpoints/spillway/r16/lab-os-final/attempt3/`. `RESULTS.json` passes **10/10 checks**, no exception; engine log is clean, Quit exits 0, earlier profiles remain unchanged, AMD drawing is confirmed and the private display and RAM scratch are removed. HOME had 16,148,111,360 bytes available before launch, above 15 GiB. Only displays 196–199 are eligible; the existing helper verifies desktop `:0` before and after.

The independently reduced `ROOT-MEASUREMENTS.json` reads the complete observation stream:

- Landing slide at observation tick 396: entry **250 u/s**, Space and Shift still held, no Ctrl. First stored slide speed **249.5117 u/s**, matching the declared 0.25 friction for one 128 Hz step. The slide does not discard the landing speed.
- The fresh Space press makes the next jump after more than 24 slide ticks. No intervening autohop occurs with held Space. The body leaves support with positive vertical velocity and the slide ends for `jump`.
- Wall kicks at ticks **1088** and **1141**: A then D remains held, W is absent, and the budget becomes **1 then 0**.
- The actual chamber landing at tick **1223**, feet about **3.227 m**, refills the budget to **2**. Zero respawns. The slightly early grounded height is the approved runner's support probe, not a placed pose.

Five player-camera JPEGs remain; root opened the landing-slide and second-kick views. The visible panel shows LANDING SLIDE with the fresh-press instruction and, at the second wall, 0/2 kicks remaining. Two sealed attempt recordings (439 and 606 ticks) pass the folder analyzer with zero unexplained teleports. The first ends when the OS menu starts checkpoint practice; the second ends at Quit. Neither is a finished clean course or a fabricated best. Full raw-key and state streams are retained as verified gzip, plus command/phase journals and GPU/display ownership records.

Executed identities:

| Item | SHA-256 |
| --- | --- |
| Linux ZIP | `f8ae42da4c55d9675056033a462310642519bba194001ecfa92c03058a841320` |
| Game pack | `845d727694efee6bbbf143d770db7a9971ecd2e69124949064945265701493f1` |
| Driver | `dc644af3b48bb7c6ab78c54ce0e92996f8dd326c1f503348b101b7a27a35deb1` |
| Read-only observer | `58f17bfc2a3859211ac0eecb2309708c132c2102c59473ecda655af20b8948e3` |

The exact executed test sources are also retained compressed beside the receipts. No production, preset, map, helper, pack or ZIP changed for this check.

## Retained failed attempts

Attempt 1 missed the one-tick grounded interval while polling the latest state. It kept hopping until the rack face stopped it, then tried to slide at zero speed and was correctly refused. It timed out. The driver now observes a cumulative jump counter instead of trying to sample a transient landing.

Attempt 2 completed the slide/hop chain but the test's blind popup keystrokes selected stage 3 rather than stage 2. It timed out at the menu. The driver now checks the popup's actual focused item before confirming. The unnamed Quit button is also reached by its visible text, not a guessed node name. Both failures retain their streams, partial recordings, source hashes and exact test sources. Their forced cleanup is not counted as a normal successful player exit.

The 199-check actual-host suite, complete packed lab route and larger-speed native chain remain separate proofs in [RESULTS.md](RESULTS.md) and [NATIVE-ACCEPTANCE.md](NATIVE-ACCEPTANCE.md). The unchanged grapple is exercised there; this focused OS test ends on the mezzanine. Windows, physical-device latency, performance and feel remain unverified.
