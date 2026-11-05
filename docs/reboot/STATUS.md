# Spillway handoff

2026-11-05. **Design chosen; runtime work has not started.** Mike's played feedback rejected the pre-reboot result despite its automated checks. This planning handoff is not a claim that the game has been fixed.

The chosen direction is [BRIEF.md](BRIEF.md): keep Godot, replace the controller, and build one finished sunlit dam-descent level around downhill speed, safe/faster route choices and forgiving recovery. [COUNCIL.md](COUNCIL.md) contains Sol's proposal, Opus's challenge and the lead's amendments. Gemini failed at provider startup and contributed nothing. [decisions.tsv](decisions.tsv) is the evidence trail. [GOAL.txt](GOAL.txt) is ready to paste to start the sustained build.

Runtime baseline: `86bb26c754424f9cb0c36b5c5fff5f6a8fc94874`, clean and pushed before this documentation change. No tests were rerun for this planning-only commit. Existing checks establish historical behavior, not enjoyable movement.

Next: implement the new motor and representative Crest slice together. Challenge real inputs, slope/stair collision, recovery, camera and rendered composition before expanding into Sluice yard and Outflow. Do not resume source-fidelity polish. The new game, its evidence and delivery remain to be built.

The first Opus consultation began around 16:42 CET; the next must start no earlier than 17:45 CET. Use subsequent hourly opportunities on consequential code or rendered artifacts. The sustained build runs until at least 20:00 Europe/Prague today. Mike is unavailable; no decision needs a mid-run reply from him.

Human enjoyment, comfort and native Windows play remain unverified. The current Linux and Windows source launch instructions remain in the project README; that README clearly labels the current game as the historical baseline.

Review scope: Opus challenged the design and initial trail; Sol challenged the synthesized contract. A narrow final Gemini audit retry also failed before session open. Final wording and local links were self-checked. No game tests or new rendered runs are claimed by this documentation checkpoint.
