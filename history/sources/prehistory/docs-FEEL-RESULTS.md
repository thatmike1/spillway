# Verified feel results

Runtime verified at `cc2756d1`. The footage-first revision is complete against its automated targets. The game opens in the original training yard. Tab switches to the city; F3 toggles metrics; R resets immediately.

| Check | Result |
|---|---|
| Flat sprint jump | .7917s, 1.267m rise; 2.8m ledge needs grab |
| Ordinary landing | Flat/1m/3m, W held/released: 6.55m/s from 7.2 pre-jump; 7.062 on first continuation frame |
| Actual fall classification | 3m ordinary; actual 6m yard station hard; support-plane measurement excludes apex and capsule rounding |
| Sprint onset / turning | Visible streak envelope 2.375s; 30°/s run 7.0168 vs straight 7.1904m/s (97.59%) |
| Low sprint vault | Every tick forward; minimum 5.6169m/s (78.01%); 7.2 at release |
| Roll | 3.13517m over P .65s active ownership; outgoing 4.82334m/s matches last motion, no zero dip |
| Presentation | FOV up to +5°, gait/arms/wind/streaks use swept travel; one comfort option reduces camera and streaks |
| Default-volume wind | Actual capture −23.1dBFS RMS, −10.3 peak; isolated wind at 7.2m/s, master .8 |
| City | 83.9333s, bank on/off, zero respawns, every move; rendered bank-off run 82.0167s |
| Yard chain | Both rendered laps 13.6917s, zero respawns, all requested chained actions |
| Verification | Clean sparse-clone Bash and PowerShell checks: 311 assertions plus two routes; rendered interface 9/9 |

The two self-review passes covered complete city and yard captures. The first found weak streak onset, low sprint arms, gait cadence and buffered bot input. Fixes were checked in the second pass. Dense vault, roll and hard-landing strips supplement per-tick body/camera checks through release +1/+2/+10. Reviews do not establish human acceptance of subjective feel.

New values/transfers are labelled P: effective free-flight gravity 16 (stored default 8 retained), air-speed cap, support-plane fall metric, released-input one-frame carry, .65s active roll distinct from nominal 1.26667s clip metadata, continuous vault path, yaw input scale .05, original eye/body/effects and 3.84m gait. Independent horizontal wall-run accelerations remain 8.2/5; jump launch remains 6.3. Coyote/buffer remain optional and off.

PowerShell 7.6.9 ran the real Linux engine from a clean path containing spaces, including fresh import and yard-first launcher checks. Native Windows gameplay and physical controllers remain untested. No further milestone-7 visual polish was attempted. Private evidence, references, captures and the external source addendum remain outside Git.
