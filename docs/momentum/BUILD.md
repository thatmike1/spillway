# Overflow: the next playable Spillway course

Moderator decision after both council rounds, 7 November. All proposed behavior and values
are P choices. Mike rejected R12 as a whole; neither its air law nor another single cause
has been established as his objection. The council's full posts are in COUNCIL.md.

Build a downhill hop course with a complete ordinary line, an earned diagonal shortcut and
a catch walk that physically reconnects. Height supplies momentum; side-key technique can
add speed; W and mouse place a jump without supplying a free speed reward. A poor approach
should cost a line or time and remain playable. Surf, automatic mantle, slide and hidden
crest launches stay out of this first course. This is one game direction, not a menu of
unrelated mechanics. A concise course can precede expansion into a second level.

## Controller comparison

Implement one new CARRY controller with two air-gain profiles and common ground/contact
policy. Retain R12 and corrected FLOW as diagnostic controls. Do not change the current
default game until the new course is integrated and checked.

- **Broad, provisional candidate:** side-key projection allowance 8.5 m/s, coefficient
  0.468/s, the council's initial peak-matched experiment at 13 m/s.
- **Narrow control:** allowance 0.75 m/s, coefficient 12/s at 120 Hz. Side-only airborne
  behavior is the R12 control; this is not a claim of exact CS or VHOLUME fidelity.
- Projection acts on the side-key contribution. W provides bounded, speed-neutral steering,
  initially 14 m/s² lateral authority with a 45–90 degree view-offset fade. W+A/D blends
  continuously toward the full movement wish, weighted by its forward contribution. It
  does not erase the sideways intent by always aiming at camera-forward. Check fixed-view
  diagonals for bounded acceleration; steering must not reopen an infinite side-gain loop.
  No input preserves the ballistic horizontal line. S brakes before reversal.
- Shared initial run/jump/body/gravity/camera remain R12's for attribution. Air profiles
  are different gain/steering laws, not merely different forgiveness: matching peak gain
  does not match angular authority. Measure both rather than calling them equivalent.
- Ground turning bends heading with bounded grip, initially 20 m/s² above run speed and
  more responsive grip at ordinary speed. Keep earned overspeed with 2 m/s² pushing drag
  initially; coasting and opposing braking are distinct. Begin with 80 ms landing grace.
  Do not import Source's 4/s overspeed friction or preserve R12's 8 m/s² tax by habit.
- Supported descent should pay and climbs should spend speed, with explicit slope/contact
  accounting. Use no per-hop or mouse-angle bonus. A real edge carries supported motion;
  a continuous crest has no threshold boost. Grounding flicker must not farm grace/energy.
- Any emergency limit must be visible in the motion ledger. Retaining the inherited
  30 m/s safety envelope for the first comparison is allowed; normal lines hitting it
  require review rather than silently clipping the intended game economy.

Choose broad provisionally because forgiving ordinary correction and usable side keys fit
the new direction. Narrow remains essential to challenge that choice. Keep broad only if
it improves imperfect approaches across a neutral and mirrored/offset layout while leaving
a useful strafe/approach reward. A higher speed, lower spread or perfect bot finish cannot
decide alone. The turn tax proposed by Opus is deferred; add it only for a demonstrated
loss of meaningful approach/braking choice. These decisions can change after actual play.

## Contacts and state

Start with the existing CharacterBody3D collision path, reporting full requested/resolved
motion and actual displacement. Publish a motion-state record for consumers. Preserve
free-look, input ownership and interpolation; no test driver writes a trajectory.

Compare a reproduced lip/seam under explicitly selected Godot Physics and Jolt with the
same motor and geometry. Then compare grouped abutting deck shapes on the same backend.
Only a remaining relevant catch justifies an owned sweep/step implementation. Changing
backend, geometry and ownership together cannot identify a cause. An engine switch is not
required to fix our own velocity restoration. Do not migrate historical R12 consumers
merely to make them use a new architecture; wire the new game to the new report.

## Course, art and delivery

Freeze a neutral jump/turn block before either profile is tuned against it. Size basic gaps
from the shared W/jump envelope with imperfect-input clearance, and leave room for both
turn radii. The diagonal must need a better approach while its miss lands on recovery.
Keep a mirrored bend and landing offset as holdouts. Build a visible start-to-finish purpose
and immediate restart, clear personal progress and replay value. A ghost can follow once
the actual motion is stable; it cannot substitute for the first finished loop.

Use the separate licensed material kit for coherent concrete/steel/brick scale and readable
landings. Compare presentation on a fixed motor/tape before bundling it into the candidate.
The finite tape executor provides relative inputs, real sampling boundaries, replay and
moving evidence. It is supporting infrastructure, not a trained enjoyment judge.

Deliver a distinct current build with Linux/Windows packages, source/asset/helper hashes,
records separate from R12, correct controls and REPORT.md. Verify the ordinary line,
mastery shortcut, physical recovery, restart/practice/pause and save/reload in the game.
Retain failures and actual native moving evidence. Native Windows execution, desktop GPU
cadence and Mike's satisfaction remain unverified until those paths are exercised. Godot
is the provisional product engine; a measured contact, pacing, art or delivery blocker
can justify the bounded alternative described in the council.
