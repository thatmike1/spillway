import math,struct
class Rejected(ValueError):
    pass
DIRECTION_UNITS = {'backward_bhop': 160, 'sideways_bhop': 50}

DIRECTION_FORMULA = 'unit*n*(n-1)/2'

DIRECTION_BANK_REASONS = frozenset(('finish', 'facing', 'ground_dwell', 'no_motor_jump',
    'flight_timeout', 'flight_short', 'travel_short', 'rise_short', 'fall_short',
    'efficiency', 'heading', 'novelty'))

def require(condition, reason):
    if not condition:
        raise Rejected(reason)


def strict_legacy_style(value, at):
    require(isinstance(value, dict) and value.get('tick') == at and value.get('v') == 1, 'invalid R20 style tick/schema')
    require(value.get('kind') in ('speed', 'sync', 'gap', 'edge', 'near_miss', 'crouch_save', 'backward_bhop', 'sideways_bhop'), 'unknown R20 style kind')
    base, mult, points = value.get('base'), value.get('mult'), value.get('points')
    direction, combo = value.get('direction_mult'), value.get('combo_mult')
    require(type(base) is int and 0 < base <= 1500 and type(points) is int and 0 < points <= 18000, 'invalid R20 style points/base')
    require(type(direction) in (int, float) and math.isfinite(direction) and 1 <= direction <= 4
        and type(combo) in (int, float) and combo in (1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3)
        and type(mult) in (int, float) and math.isfinite(mult) and math.isclose(mult, direction * combo, abs_tol=1e-9)
        and abs(points - base * mult) <= (mult + 1) / 2 + 1e-8, 'invalid R20 direction/combo product')
    require(isinstance(value.get('m'), dict) and isinstance(value.get('geo'), dict) and isinstance(value.get('label'), str) and bool(value['label']), 'invalid R20 style detail')


def finite_number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False


def strict_stack_style(value, at):
    """validate a bank independently of the ordinary combo and its legacy point ceiling."""
    fields = {'v', 'kind', 'tick', 'time_s', 'elapsed', 'points', 'base', 'mult',
        'direction_mult', 'combo_mult', 'combo', 'label', 'm', 'geo', 'p', 'clean'}
    require(isinstance(value, dict) and set(value) == fields, 'invalid direction bank fields')
    require(type(at) is int and at >= 0 and type(value['tick']) is int
        and value['tick'] == at and type(value['v']) is int and value['v'] == 2, 'invalid direction bank tick/schema')
    measures = value['m']
    require(isinstance(measures, dict) and set(measures) == {'direction', 'hops', 'unit',
        'formula', 'reason', 'start_tick', 'last_hop_tick', 'end_ups'}, 'invalid direction bank measures')
    direction, hops = measures['direction'], measures['hops']
    require(isinstance(direction, str) and direction in DIRECTION_UNITS
        and value['kind'] == direction + '_bank', 'invalid direction bank kind')
    require(value['label'] == ('Backwards banked' if direction == 'backward_bhop' else 'Half-sideways banked'),
        'direction bank label differs from its category')
    require(type(hops) is int and 2 <= hops <= at + 1
        and type(measures['unit']) is int and measures['unit'] == DIRECTION_UNITS[direction]
        and measures['formula'] == DIRECTION_FORMULA, 'invalid direction bank formula')
    expected = DIRECTION_UNITS[direction] * hops * (hops - 1) // 2
    require(type(value['base']) is int and type(value['points']) is int
        and value['base'] == value['points'] == expected, 'invalid direction bank points')
    require(all(finite_number(value[key]) and value[key] == 1
        for key in ('mult', 'direction_mult', 'combo_mult'))
        and type(value['combo']) is int and value['combo'] == 0, 'direction bank must be outside the ordinary combo')
    require(type(measures['start_tick']) is int and type(measures['last_hop_tick']) is int
        and 0 <= measures['start_tick'] < measures['last_hop_tick'] <= at
        and hops <= measures['last_hop_tick'] - measures['start_tick'] + 1, 'invalid direction bank hop ticks')
    require(isinstance(measures['reason'], str) and measures['reason'] in DIRECTION_BANK_REASONS
        and finite_number(measures['end_ups']) and measures['end_ups'] >= 300, 'invalid direction bank end')
    require(all(finite_number(value[key]) and value[key] >= 0 for key in ('time_s', 'elapsed'))
        and type(value['clean']) is bool and value['geo'] == {}
        and isinstance(value['label'], str) and bool(value['label'])
        and isinstance(value['p'], list) and len(value['p']) == 3
        and all(finite_number(component) for component in value['p']), 'invalid direction bank observation')


def strict_direction(value, at):
    """validate the payload tick; queued loss envelope attribution is a separate audit."""
    fields = {'record_kind', 'v', 'kind', 'reason', 'serial', 'tick', 'time_s',
        'direction', 'hops', 'pending', 'unit', 'formula', 'm'}
    require(isinstance(value, dict) and set(value) == fields, 'invalid direction diagnostic fields')
    require(type(at) is int and at >= 0 and type(value['tick']) is int and value['tick'] == at
        and type(value['v']) is int and value['v'] == 1 and value['record_kind'] == 'direction', 'invalid direction diagnostic tick/schema')
    direction, hops = value['direction'], value['hops']
    require(isinstance(direction, str) and direction in DIRECTION_UNITS
        and type(hops) is int and 1 <= hops <= at + 1
        and type(value['unit']) is int and value['unit'] == DIRECTION_UNITS[direction]
        and value['formula'] == DIRECTION_FORMULA, 'invalid direction diagnostic formula')
    require(type(value['pending']) is int
        and value['pending'] == DIRECTION_UNITS[direction] * hops * (hops - 1) // 2,
        'invalid direction diagnostic amount')
    require(type(value['serial']) is int and value['serial'] > 0
        and finite_number(value['time_s']) and value['time_s'] >= 0
        and isinstance(value['m'], dict), 'invalid direction diagnostic observation')
    require(isinstance(value['reason'], str) and bool(value['reason']), 'missing direction diagnostic reason')
    require(value['kind'] in ('direction_pending', 'direction_banked', 'direction_lost'), 'invalid direction diagnostic kind')
    if value['kind'] == 'direction_pending':
        require(value['reason'] == 'eligible', 'invalid pending reason')
        measures = value['m']
        require(set(measures) == {'air_s', 'track_m', 'progress_m', 'rise_m', 'fall_m',
            'heading_dot', 'landing_ups'} and all(finite_number(component) for component in measures.values()),
            'invalid pending flight measures')
        require(0.18 <= measures['air_s'] <= 1.2 and measures['track_m'] >= 3
            and measures['progress_m'] >= measures['track_m'] * 0.85
            and measures['rise_m'] >= 0.25 and measures['fall_m'] >= 0.2
            and measures['heading_dot'] >= 0.5 and measures['landing_ups'] >= 300,
            'pending diagnostic violates R19 flight eligibility')
    elif value['kind'] == 'direction_banked':
        require(value['reason'] in DIRECTION_BANK_REASONS and value['m'] == {}, 'invalid bank diagnostic reason')
    else:
        require(value['m'] == {} and value['reason'] not in ('pause', 'resume'), 'invalid loss diagnostic reason')


def strict_style(value, at):
    if isinstance(value, dict) and value.get('v') == 2:
        strict_stack_style(value, at)
        return
    strict_legacy_style(value, at)
    require(type(value['v']) is int and type(value['tick']) is int
        and value['kind'] not in DIRECTION_UNITS and value['direction_mult'] == 1,
        'R20 ordinary style must not multiply or immediately score direction')


def source_horizontal_ups(x, z):
    """reproduce the pinned float32 Vector2.length before its double source-unit division."""
    f32 = lambda value: struct.unpack('<f', struct.pack('<f', value))[0]
    x, z = f32(x), f32(z)
    return f32(math.sqrt(f32(f32(x * x) + f32(z * z)))) / 0.0254


def direction_boundary_matches(rec, event, value):
    if event.get('s') != 'event' or event.get('t') != value['tick']:
        return False
    if value['reason'] != 'tether_settings':
        return event.get('k') == value['reason']
    if event.get('k') != 'loadout' or getattr(rec, 'header', {}).get('metadata', {}).get('map') != 'tether-yard':
        return False
    data = event.get('d', {})
    if data.get('key') == 'tether_auto_reel':
        return type(data.get('from')) is bool and type(data.get('to')) is bool and data['from'] != data['to']
    if data.get('key') == 'tether_model':
        return all(type(data.get(key)) is str and data[key] in ('classic','pendulum','elastic') for key in ('from','to')) and data['from'] != data['to']
    return False


def audit_style_stream(rec, rows):
    """reconcile scored events and non-scored state transitions with post-step observations."""
    ticks = rec.columns.get('tick')
    require(isinstance(ticks, list) and ticks
        and all(type(tick) is int and tick == i for i, tick in enumerate(ticks)),
        'recorded style samples must have a complete ordered tick stream')
    require(len(rows) == len(ticks), 'style observations must cover every recorded sample')
    for i, row in enumerate(rows):
        sample = row.get('sample', row)
        require(isinstance(sample, dict) and type(sample.get('tick')) is int
            and sample['tick'] == ticks[i], 'style observations must follow recorded tick order')
    n = len(rows)
    scored = [[] for _ in rows]
    captures = [[] for _ in rows]
    lifecycle = [[] for _ in rows]
    banks = {}
    by_kind = {}
    diagnostics = []
    for event in rec.events:
        source, kind, at, value = event.get('s'), event.get('k'), event['t'], event['d']
        if source == 'capture' and kind == 'style':
            require(type(at) is int and 0 <= at < n, 'invalid style lifecycle attribution')
            strict_style(value, at)
            scored[at].append(value)
            entry = by_kind.setdefault(value['kind'], {'n': 0, 'points': 0})
            entry['n'] += 1; entry['points'] += value['points']
            if value['v'] == 2:
                key = (at, value['m']['direction'], value['m']['hops'])
                require(key not in banks, 'duplicate direction bank')
                banks[key] = value
        elif kind == 'direction':
            require(source in ('capture', 'event') and type(at) is int and 0 <= at < n,
                'invalid direction lifecycle attribution')
            require(isinstance(value, dict) and type(value.get('tick')) is int
                and 0 <= value['tick'] <= at, 'direction diagnostic refers to a future or missing sample')
            strict_direction(value, value['tick'])
            require(value['kind'] == 'direction_lost' or value['tick'] == at,
                'only a queued loss may precede its capture tick')
            require(source != 'event' or value['kind'] == 'direction_lost',
                'lifecycle must never bank or synthesize a pending landing')
            (captures if source == 'capture' else lifecycle)[at].append(value)
            diagnostics.append(value)
        elif source == 'capture':
            raise Rejected('unknown capture kind')
        elif kind == 'style':
            raise Rejected('scored style must belong to a physical capture')
    require([d['serial'] for d in diagnostics] == list(range(1, len(diagnostics) + 1)),
        'missing, duplicate or reordered direction diagnostics')
    inactive = {'kind': '', 'hops': 0, 'pending': 0, 'unit': 0}
    active, last, start_tick, last_hop_tick, total = dict(inactive), {}, -1, -1, 0

    def transition(value, at):
        nonlocal active, last, start_tick, last_hop_tick
        if value['kind'] == 'direction_pending':
            require((active['kind'] == '' and value['hops'] == 1)
                or (active['kind'] == value['direction'] and value['hops'] == active['hops'] + 1),
                'direction pending does not extend the observed chain')
            if active['kind'] == '':
                start_tick = value['tick']
            last_hop_tick = value['tick']
            active = {'kind': value['direction'], 'hops': value['hops'],
                'pending': value['pending'], 'unit': value['unit']}
            return
        require(active == {'kind': value['direction'], 'hops': value['hops'],
            'pending': value['pending'], 'unit': value['unit']}, 'direction terminal does not match the observed pending chain')
        key = (at, value['direction'], value['hops'])
        bank = banks.pop(key, None) if value['kind'] == 'direction_banked' else None
        if value['kind'] == 'direction_banked' and value['pending'] > 0:
            require(bank is not None and bank['points'] == value['pending']
                and bank['m']['reason'] == value['reason'] and bank['m']['start_tick'] == start_tick
                and bank['m']['last_hop_tick'] == last_hop_tick, 'direction bank differs from its earned diagnostic chain')
            speed = source_horizontal_ups(rec.columns['actual_v_x'][at], rec.columns['actual_v_z'][at])
            require(speed >= 300 and json_numbers_match(bank['m']['end_ups'], speed),
                'direction bank speed differs from its actual recorded sample')
        else:
            require(bank is None and key not in banks, 'lost or zero pending chain awarded a bank')
        last = value
        active = dict(inactive)

    for i, row in enumerate(rows):
        for value in captures[i]:
            if value['kind'] == 'direction_pending':
                require(finite_number(row.get('style_time_s'))
                    and math.isclose(value['time_s'], row['style_time_s'], abs_tol=0.00000051, rel_tol=0),
                    'pending diagnostic time differs from the physical style clock')
                require(json_numbers_match(row.get('style_direction_verdict'),
                    {'verdict': 'eligible', 'tick': value['tick'], 'm': value['m']}),
                    'pending diagnostic flight differs from the live detector verdict')
            transition(value, i)
        state = row.get('style_direction')
        require(isinstance(state, dict) and set(state) == {'kind', 'hops', 'pending', 'unit',
            'formula', 'suspended', 'last'} and state['formula'] == DIRECTION_FORMULA
            and state['suspended'] is False, 'independent direction observation is missing or suspended')
        require(isinstance(state['kind'], str) and state['kind'] in ('', *DIRECTION_UNITS)
            and all(type(state[key]) is int for key in ('hops', 'pending', 'unit')),
            'invalid observed direction state types')
        # a first physical flight names its direction before its zero-point landing arms.
        expected = active if active['hops'] else dict(active, kind=state['kind'],
            unit=DIRECTION_UNITS.get(state['kind'], 0))
        require({key: state[key] for key in active} == expected
            and json_numbers_match(state['last'], last), 'recorded direction transitions differ from live pending state')
        require('style_events' in row and json_numbers_match(scored[i], row['style_events']),
            'recorded style events differ from live scoring observations')
        total += sum(value['points'] for value in scored[i])
        require(type(row.get('style_score')) is int and row['style_score'] == total,
            'style score differs from live scoring observation')
        # lifecycle events are emitted after the recorder's last physical sample.
        for value in lifecycle[i]:
            require(any(direction_boundary_matches(rec, event, value) for event in rec.events),
                'direction lifecycle loss has no matching host boundary')
            transition(value, i)
    require(not banks, 'direction bank has no matching bank diagnostic')
    outcome = rec.seal['outcome']
    require(type(outcome.get('style', {}).get('score')) is int and outcome['style']['score'] == total
        and json_numbers_match(outcome['style'].get('by_kind'), by_kind),
        'style total differs from recorded and observed scored events')
    return total, by_kind


def json_numbers_match(a, b):
    """JSON engine text has 14 significant digits; binary columns use exact byte comparison."""
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(json_numbers_match(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(json_numbers_match(x, y) for x, y in zip(a, b))
    if type(a) is float or type(b) is float:
        return type(a) in (int, float) and type(b) in (int, float) and math.isfinite(a) and math.isfinite(b) and math.isclose(a, b, rel_tol=1e-13, abs_tol=1e-14)
    return a == b
