#!/usr/bin/env python3
"""Independent public-rule predictions, never a CS:GO runtime measurement.

Original equations; standard library only. See docs/r14/SOURCE-REFERENCE.md for
provenance, assumptions and unresolved vanilla landing/stamina behavior.
Run with --self-test for mathematical checks, or without arguments for JSON.
"""

import argparse
import json
import math
import unittest

GRAVITY = 800.0
JUMP_IMPULSE = 301.993377
METRES_PER_UNIT = 0.0254


def air_budget(aa, wishspeed, hz, surface=1.0, cap=30.0, capped_budget=False):
    """Return the acceleration budget, distinct from the projection ceiling."""
    if hz <= 0 or min(aa, wishspeed, surface, cap) < 0:
        raise ValueError("positive rate and nonnegative movement parameters required")
    basis = min(wishspeed, cap) if capped_budget else wishspeed
    return aa * basis * surface / hz


def air_delta(projection, budget, cap=30.0):
    """Scalar addition along a unit wish direction, not total speed gain."""
    return max(0.0, min(budget, cap - projection))


def ideal_air_step(speed, budget, cap=30.0):
    """Maximize next speed over all wish angles; no yaw-rate constraint.

    For p = v dot wishdir and addition a, next speed squared is
    s*s + 2*a*p + a*a. The optimal reachable p is min(s, C-min(B,C)).
    """
    if min(speed, budget, cap) < 0:
        raise ValueError("nonnegative speed, budget and cap required")
    addition = min(budget, cap)
    projection = min(speed, cap - addition)
    return {
        "speed": math.sqrt(speed * speed + 2 * addition * projection + addition**2),
        "wish_angle_deg": math.degrees(math.acos(projection / speed)) if speed else None,
        "projection": projection,
        "addition": addition,
    }


def ideal_air_arc(speed, ticks, budget, cap=30.0):
    """Closed form across constant-budget ticks, including a start from zero."""
    if ticks < 0 or int(ticks) != ticks or min(speed, budget, cap) < 0:
        raise ValueError("nonnegative speed/budget/cap and integer ticks required")
    b = min(budget, cap)
    if b == 0 or ticks == 0:
        return speed
    # until the optimum projection is reachable, the best input is aligned.
    aligned = min(ticks, max(0, math.ceil((cap - b - speed) / b)))
    s = speed + aligned * b
    return math.sqrt(s * s + (ticks - aligned) * b * (2 * cap - b))


def ground_tick(speed, hz, wishspeed=250.0, accel=5.5, friction=5.2,
                stopspeed=80.0, surface=1.0):
    """One straight ground tick: friction, then forward acceleration.

    Knife-like 250u/s, weapon-speed acceleration basis set to wishspeed. Other
    weapon encumbrance and inventory policies are outside this fixture.
    """
    retained = max(0.0, speed - max(speed, stopspeed) * friction * surface / hz)
    return retained + max(0.0, min(accel * wishspeed * surface / hz, wishspeed - retained))


def friction_closed(speed, ticks, hz, friction=5.2, stopspeed=80.0):
    """Exact flat-ground release: geometric above stopspeed, linear below."""
    q = 1.0 - friction / hz
    if speed < 0 or ticks < 0 or int(ticks) != ticks or not 0 < q < 1 or stopspeed <= 0:
        raise ValueError("invalid friction fixture")
    geometric = min(ticks, max(0, math.ceil(math.log(stopspeed / speed) / math.log(q)))) if speed > stopspeed else 0
    s = speed * q**geometric
    return max(0.0, s - (ticks - geometric) * friction * stopspeed / hz)


def ground_runup(hz):
    s, ticks = 0.0, 0
    while s < 250.0 and ticks < 10000:
        s = ground_tick(s, hz)
        ticks += 1
    if s != 250.0:
        raise RuntimeError("runup failed to reach target")
    return {"ticks": ticks, "seconds": ticks / hz, "speed_u_s": s}


def ballistic(hz, source_standing_order=False):
    """Sample an analytic parabola; no collision/contact solver is implied.

    source_standing_order applies an extra half gravity tick to the effective
    initial impulse, derived from the public Source2013 standing jump ordering.
    This is a sensitivity case, not a verified CS:GO engine ordering claim.
    """
    effective = JUMP_IMPULSE - (GRAVITY / (2 * hz) if source_standing_order else 0.0)
    apex_time = effective / GRAVITY
    flight = 2 * apex_time
    landing_tick = math.ceil(flight * hz)
    closest = round(apex_time * hz)
    sampled_apex = effective * closest / hz - GRAVITY * (closest / hz)**2 / 2
    return {
        "effective_impulse_u_s": effective,
        "apex_time_s": apex_time,
        "continuous_apex_u": effective**2 / (2 * GRAVITY),
        "sampled_apex_u": sampled_apex,
        "equal_height_airtime_s": flight,
        "first_nonpositive_height_tick": landing_tick,
        "sampled_flight_s": landing_tick / hz,
    }


def hop_chain(hz, aa, hops, capped_budget=False, source_standing_order=False,
              deadstrafe=False, takeoff_limit=None):
    """Idealized maximum for a fully specified, stamina-free hop fixture.

    Start stationary on a flat plane. W runup to exactly 250, release W; hop
    with ideal A/D and freely chosen same-direction yaw. Re-jump immediately,
    with no ground friction tick. Count air updates through the plane-crossing
    tick. No collisions, stamina, speed ceiling, or finite-yaw restriction.
    An optional takeoff_limit is an explicit sensitivity policy, not vanilla.
    """
    if hops < 0 or int(hops) != hops:
        raise ValueError("nonnegative integer hops required")
    timing = ballistic(hz, source_standing_order)
    count = timing["first_nonpositive_height_tick"]
    effective = timing["effective_impulse_u_s"]
    s = 250.0
    values = []
    for _ in range(hops):
        if takeoff_limit is not None:
            s = min(s, takeoff_limit)
        for tick in range(count):
            # midpoint classification is a declared approximation to engine
            # CategorizePosition timing, useful for a deadstrafe sensitivity.
            vz = effective - GRAVITY * (tick + 0.5) / hz
            surface = 0.25 if deadstrafe and 0.0 < vz <= 140.0 else 1.0
            budget = air_budget(aa, 250.0, hz, surface, capped_budget=capped_budget)
            s = ideal_air_step(s, budget)["speed"]
        values.append(s)
    return {"landing_speeds_u_s": values, "air_updates_per_hop": count,
            "runup": ground_runup(hz), "stamina": "disabled",
            "takeoff_limit_u_s": takeoff_limit, "deadstrafe_midpoint_model": deadstrafe}


def report():
    rows = []
    for hz in (64, 128):
        for aa in (12, 100):
            for capped in (False, True):
                b = air_budget(aa, 250, hz, capped_budget=capped)
                step = ideal_air_step(250, b)
                rows.append({"hz": hz, "aa": aa, "wishspeed_u_s": 250,
                             "budget_mode": "capped" if capped else "legacy_uncapped",
                             "surface": 1, "budget_u_s": b,
                             "optimal_wish_angle_deg": step["wish_angle_deg"],
                             "optimal_tick_gain_at_250_u_s": step["speed"] - 250,
                             "optimal_16_tick_arc_end_u_s": ideal_air_arc(250, 16, b),
                             "five_hops_ideal_impulse": hop_chain(hz, aa, 5, capped),
                             "five_hops_source_standing_order": hop_chain(hz, aa, 5, capped, True),
                             "five_hops_deadstrafe_sensitivity": hop_chain(hz, aa, 5, capped, True, True)})
    return {
        "classification": "calculated public-rule predictions, no external runtime observations",
        "input": "ground W runup, airborne A/D ideal wish angle and unrestricted yaw, no W",
        "weapon": "declared knife-like 250u/s; ground accel basis 250; surface 1",
        "jump_policy": "autohop, no stamina, no takeoff clamp, no grounded friction between hops",
        "units": {"metres_per_u": METRES_PER_UNIT, "gravity_u_s2": GRAVITY,
                  "impulse_u_s": JUMP_IMPULSE, "air_projection_cap_u_s": 30},
        "ballistic": {str(hz): {"ideal": ballistic(hz), "source_standing_order": ballistic(hz, True)} for hz in (64, 128)},
        "air_rows": rows,
        "ground_release_250": {str(hz): {"first_tick_u_s": friction_closed(250, 1, hz),
                                         "after_32_ticks_u_s": friction_closed(250, 32, hz),
                                         "runup": ground_runup(hz)} for hz in (64, 128)},
        "vanilla_exact_hop_maximum": None,
        "vanilla_limitation": "landing stamina and contact order not independently measured; no fabricated exact maximum",
    }


class OracleChecks(unittest.TestCase):
    def test_optimum_against_angle_sweep(self):
        for s in (0, 1, 10, 30, 250, 1000):
            for b in (0, 2.8125, 11.71875, 23.4375, 46.875, 390.625):
                best = ideal_air_step(s, b)["speed"]
                brute = 0.0
                for i in range(36001):
                    p = s * math.cos(i * math.pi / 36000)
                    a = air_delta(p, b)
                    brute = max(brute, math.sqrt(max(0, s*s + 2*a*p + a*a)))
                self.assertGreaterEqual(best + 1e-9, brute)
                self.assertLess(best - brute, 0.001)

    def test_closed_arc_matches_steps(self):
        for s in (0, 1, 10, 250):
            for b in (0, 2.8125, 11.71875, 23.4375, 46.875):
                for n in (0, 1, 2, 16, 100):
                    repeated = s
                    for _ in range(n):
                        repeated = ideal_air_step(repeated, b)["speed"]
                    self.assertAlmostEqual(ideal_air_arc(s, n, b), repeated, places=10)

    def test_frictions_closed_form(self):
        for hz in (64, 128):
            for initial in (0, 1, 79, 80, 81, 250, 1000):
                for n in (0, 1, 32, 128):
                    s = initial
                    for _ in range(n):
                        s = max(0, s - max(s, 80) * 5.2 / hz)
                    self.assertAlmostEqual(friction_closed(initial, n, hz), s, places=10)

    def test_semantics_and_discriminating_values(self):
        self.assertEqual(air_budget(12, 250, 64), 46.875)
        self.assertEqual(air_budget(12, 250, 64, capped_budget=True), 5.625)
        self.assertEqual(air_delta(31, 100), 0)
        self.assertEqual(air_delta(-100, 100), 100)
        self.assertAlmostEqual(ideal_air_step(250, 46.875)["speed"]**2, 250**2 + 900)
        self.assertAlmostEqual(ballistic(64)["continuous_apex_u"], 57, places=6)
        self.assertEqual(ballistic(64)["first_nonpositive_height_tick"], 49)
        self.assertEqual(ballistic(128)["first_nonpositive_height_tick"], 97)
        self.assertEqual(ballistic(64, True)["first_nonpositive_height_tick"], 48)
        self.assertEqual(ballistic(128, True)["first_nonpositive_height_tick"], 96)
        self.assertAlmostEqual(hop_chain(128, 100, 5, source_standing_order=True)["landing_speeds_u_s"][-1], math.sqrt(250**2 + 5*96*900))
        self.assertEqual(ground_tick(0, 64), 21.484375)
        self.assertEqual(hop_chain(64, 100, 0)["landing_speeds_u_s"], [])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        unittest.main(argv=[__file__], verbosity=2)
    else:
        print(json.dumps(report(), indent=2, allow_nan=False))
