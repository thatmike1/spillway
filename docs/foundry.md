# Foundry

Foundry is a coastal pump hall with an open shaft between two working galleries.
Its landmark is the supported crane spanning the shaft, with a ring suspended over the void.
From the high entry, the player sees the continuous left gallery and the lower far landing at once.
A released swing takes the direct line while a wide descending gallery provides a forgiving alternative.
Beyond their meeting point, the tailrace drops another ten metres into a broad catch above the recovery court.

## Route plan (metres)

```text
                         x=-16 gallery       x=0 direct
spawn y18 z12 -------------+---------------------+
                           |                     |
                           |       crane (0,29,-8)
             ring (-16,25,-12)                  void
                           |                     |
rejoin y12 z-28 -----------+---------------------+
                                                 |
                                  crane (0,21,-40)
                                                 |
catch y2 z-50 ----------------------------------+
finish y2 z-70
court y-8: full floor, outer return ramp to entry; right ramp to tailrace
```

The Arc law is inherited unchanged from `movement/grapple_player.gd`.
Anchor IDs are `foundry-0`, `foundry-1`, `foundry-2`.
The dedicated geometry identity is `r22-foundry`, version 1.
No checkpoint is required to take the shortcut; checkpoints provide practice poses.
Private concept art lives outside the repository in the lane run folder.

The scored checkpoints are on the shared entry, rejoin and tailrace decks.
The wall gallery has no exclusive scored checkpoint, so taking the direct shaft
cannot make an otherwise complete run incomplete.

## Input proof

`tests/foundry_routes.gd` constructs command tapes with forward/jump/rope buttons
and view angles. It uses the production runner and collision geometry at 128 Hz,
normal authored spawn, server128 settings, Arc and explicit LMB/RMB input. It never
writes velocity or position during a route. Input construction may follow a
waypoint; the eventual fixed tape replay is the independent acceptance step.

## Spacing check against lane 12's measured sheet

Read `/home/thatmike1/spillway-r22-run/reference/MAP-DESIGN.md` (17 Nov,
first measured sheet). Its dominant `bhop_eazy` mover pads (180 of 188) are 64 Source units
(1.6256 m), with eight narrow or angled exceptions, compared with this map's 12 m gallery, 32 m shared landing and 20 m tailrace catch.
Those generous surfaces are intentional recovery space, not borrowed bhop tier
numbers. The sheet supplies no route-only rope gaps; it cannot validate the
20 m shaft or 14 m descending gap. Production Arc route tapes must validate those.
Shared checkpoints sit after the crossing and descending catch, at actual
failure-section boundaries. The supported crane remains the single landmark.

Revision 2 and its independent-review correction distinguish adjacent-pad
spacing from actual landing sequences and withdraw bonus gap percentiles.
Neither establishes a comparable rope-law/anchor-spacing recommendation.
Foundry therefore keeps its independently exercised 20 m shaft and 14 m
falling catch, rather than transplanting bhop distances into a rope course.
The sequence changes elevation, contact and recovery: continuous gallery or
released crossing, common landing, descending catch. Nothing downloaded is used.

## Measured greybox acceptance

The production runner completed the gallery in 2001 ticks (15.6328125 s) and
the shaft line in 1238 ticks (9.671875 s). Both collected all shared checkpoints
and earned the descending catch. Mouse-input replay reproduced each final
position exactly. The shortcut saved 763 ticks (5.9609375 s). A deliberate fall
to the court then climbed the outer ramp back to the entry in 5140 ticks,
without a reset. These are scripted acceptance measurements, not a playtest.

The direct tape holds the shaft ring for 140 ticks, releasing before passing
beneath it. Earlier releases tested short; later holds tested past the useful
forward phase. Recovery remains available below either miss.
