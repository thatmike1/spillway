# Recorded platform-clip inputs

`tools/r21-clip-fixture.py` extracts a private replay input tape and observed tick window from one strictly readable, sealed R20 Tether Yard F2 recording. It runs no engine and proves no contact cause.

From `projects/foldrunner`, pass an original recording, a new absolute output directory under `/tmp`, and inclusive recorded tick numbers:

```sh
python3 -I tools/r21-clip-fixture.py "$recording" --out /tmp/private-clip-fixture --first 306 --last 436
```

The output contains all raw key, mouse-button and mouse-motion input rows in their original order, plus all derived action rows for independent reconciliation. The expected observation window retains every recorded tick column. Provenance binds the source bytes, unchanged strict reader, extractor, full header, seal and output hashes. Inputs and positions are private playtest data: keep these outputs outside Git and the portable build.

Inject raw events before the physics step whose post-step sample has that same recorded tick. Recreate the normal R20 spawn and recorded model, reel, sensitivity and look settings. Do not use the first post-step position as a spawn placement. Require the full original physical trace to match before comparing revised geometry. An extracted tape alone does not establish that its engine execution has matched.

Parent preparation selected these three windows from the analysis:

| Recording time | Inclusive window | Candidate |
|---|---:|---|
| 10:42:45 | 1082–1211 | Manual Elastic, dispatch front at ticks 1146–1147 |
| 10:47:15 | 1463–1592 | Automatic Elastic, dispatch front at ticks 1527–1528 |
| 10:43:00 | 306–436 | Manual Elastic, first transfer at ticks 370–372 |

Across these originals, 3,383 raw input rows were preserved and 3,807 recorded yaw/pitch pairs were reconstructed exactly from the ordered mouse counts and recorded sensitivity. The latter supports the tick ordering and input data, not physical replay. Nine extraction refusal cases and one byte-exact CLI reproduction passed. Receipts are in outer `look/evidence/r21-recorded-clip-preparation.json`; private tapes are under `/tmp/r21-recorded-clips-02`. Collider normals, rope state and minimal clearance comparisons remain engine work.
