# Mail Roofs

A postal quarter climbs out of the harbour around an open tidal atrium.
Its landmark is the sorting clock tower above the north roof, visible from spawn across the court.
The runner starts on the broad south roof and sees two pale roof promenades wrapping the deep courtyard.
Five collection slots sit on the connected buildings, with no prescribed delivery order.
At the north sorting house an envelope window leads into a chamber whose supported chimney hides slot 03, so the flight must bend inside before returning to the same hop.

## Rules and choices

Map ID `mail-roofs` has its own geometry and runner identity. It extends the [Mail Run mechanic](mail-run.md), preserving the inherited F2 motor, 24 m/s envelope and 1.6-second flight limit. Default: held body, envelope camera, all five deliveries required before returning to Dispatch. B compares a running body, V compares cameras, and N makes mail optional. Changes restart with separate best/record identities. Different delivery orders share the same identity.

Both directions around the atrium are valid. Open slot numbers remain in the ticket; completed plates say SENT. No single next target is imposed. The north chamber has a 1.6 × 0.8 m window: lower than the F2 crouched hull. The chimney blocks straight lines from the window to the receiving area, with turning room to its east. The opening is physical occlusion, not a painted suggestion.

The sole practice checkpoint restarts the complete roof loop, with all five slots still required and no clean-best eligibility. A miss costs steering time and permits retry. Optional mail is a separate direct-return experiment: it imposes no roof-loop requirement, so reaching nearby Dispatch without deliveries is allowed.

## Presentation

Connected service galleries, a roof lantern on the later gallery, a supported Dispatch doorway and a west wharf/warehouse/gantry give the loop its setting. Roof joints, restrained weather at joints/waterlines, shaded-face separation and local service lighting supply surface/depth cues. Pale number plates and window framing identify the receiving openings. Camera/body wording distinguishes the steering view from body hold, and the mail ticket hides at finish.

Roof mesh names deliberately avoid the shared look layer's `Mesh_*` material replacements, as the original quay does. These are visual names; collision/progress prisms retain their authored identifiers. All new geometry, shader code and fixtures are original procedural work. References and the generated concept stay outside Git; none is a runtime asset.

## Verification

Choose fresh external paths; captures use the wrapper's private display. From this checkout:

```sh
mkdir -p /tmp/r22-mail-roofs-tapes
python3 tools/play.py --headless --audio-driver Dummy --fixed-fps 128 --script res://tests/mail_roofs.gd -- --mail-roofs-out=/tmp/r22-mail-roofs-tapes
python3 tools/play.py --headless --audio-driver Dummy --fixed-fps 128 --script res://tests/mail_roofs_modes.gd
python3 tools/play.py --headless --audio-driver Dummy --fixed-fps 128 --script res://tests/mail_material_startup.gd
python3 tools/shot.py --map mail-roofs --tape /tmp/r22-mail-roofs-tapes/clockwise.json --seconds 34 --every 1 --out /tmp/r22-mail-roofs-frames
python3 -B tests/mail_roofs_match.py --expected /tmp/r22-mail-roofs-tapes/clockwise.expected.json --startup-expected /tmp/r22-mail-roofs-tapes/clockwise.expected.json --frames /tmp/r22-mail-roofs-frames/frames.jsonl --out /tmp/r22-mail-roofs-match.json
python3 tools/test.py --out /tmp/r22-mail-run/fresh-fast
```

The native executor delivers and finishes in both orders from normal spawn, with no body placement or velocity seeding. It checks clean eligibility, recorded displacement continuity, direct-flight obstruction and 16 window/receiving-area corner rays. Its late-physics observer checks active camera/body wording, completed plates and finish-ticket visibility at the phase used by forced captures. The prior idle-only implementation fails that observer in the retained external red regression.

`mail_roofs_modes.gd` exercises all eight public body/camera/goal combinations: distinct identities, pause preservation, five-slot counters and getters, required/optional finish rules, and dirty full-loop practice.

`mail_material_startup.gd` checks both mail maps from an absent profile: the default painted sky/ink remains enabled, authored floor shaders survive L on/off/on, and record identity stays unchanged.

`mail_roofs_match.py` compares sampled rendered body positions, delivery/flight/finish states and default comparison settings against the native export, and requires a clean five-delivery end. The tests use a proportional aiming controller; they prove feasibility, not human comfort, optimal route or enjoyment. Software-rendered frames do not establish hardware performance. Original-map slow parity and candidate packaging belong to the integrator during this run.
