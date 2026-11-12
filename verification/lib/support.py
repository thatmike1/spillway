import copy,gzip,hashlib,itertools,json,math,struct
from pathlib import Path
import transport as B
import scoring as P
import run_reader as A
C=B.C
STYLE_ID = {'event_format': 2, 'rules_sha256': 'b133b80f118247cf944f1c48bbe9f1a65e2b71653adff52d41563904be661688', 'version': 'r20-style-stack-1'}

STYLE_KEY = STYLE_ID['version'] + '/' + str(STYLE_ID['event_format']) + '/' + STYLE_ID['rules_sha256'][:16]

IDENTITY_KEYS = {'course_key','format','geometry','map','motor','overlay','physics_hz','preset','runner','timing'}

META_KEYS = {'attempt','build','build_label','clean_at_start','course_key','elapsed_at_start','family','held_actions','identity','lab','laws','look','map','map_kind','map_name','opportunities','overlay','paused_at_start','physics','practice_reason','practice_stage','preset','preset_label','record_identity','sample','scoring','start_reason','timer_running_at_start'}

HEADER_KEYS = {'created_unix','created_utc','engine','format','identity','metadata','os','run_id','units','vector_precision','version'}

STYLE_FIELDS = {'v','kind','tick','time_s','elapsed','points','base','mult','direction_mult','combo_mult','combo','label','m','geo','p','clean'}

ORDINARY = {'speed','sync','gap','edge','near_miss','crouch_save'}

DIRECTIONS = {'backward_bhop','sideways_bhop'}

class Refused(ValueError):
    pass


def need(ok, reason):
    if not ok:
        raise Refused(reason)


def exact(a, b, reason):
    found = C.difference(a, b)
    need(found is None, reason + ': ' + repr(found))


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode()


def load(path):
    def pairs(items):
        result = {}
        for k,v in items:
            need(k not in result, 'duplicate JSON key: ' + k)
            result[k] = v
        return result
    return json.loads(Path(path).read_text(), object_pairs_hook=pairs,
        parse_constant=lambda value: (_ for _ in ()).throw(Refused('non-finite JSON: ' + value)))


def keys(value, expected, label):
    need(type(value) is dict and set(value) == set(expected), 'unknown/missing ' + label + ' fields')


def sha(path):
    with Path(path).open('rb') as incoming:
        return hashlib.file_digest(incoming, 'sha256').hexdigest()


def strict_event(value, legacy=False):
    keys(value,STYLE_FIELDS,'scored event')
    if legacy:
        need(value['v'] == 1 and type(value['v']) is int, 'unknown legacy scored schema')
        P.strict_legacy_style(value,value['tick'])
    else:
        P.strict_style(value,value['tick'])


def style_snapshots(rows):
    fields = {'version','identity_key','score','combo','mult','direction','combo_left_s','combo_window_s',
        'last_combo','recent','last','by_kind','clean','finished','sealed','best_eligible','time_s','context','diag'}
    diag_fields = {'speed','sync','direction','flight','gap','edge','near','crouch','verdicts','farm_blocked','discontinuities','auto_breaks'}
    cumulative=[]; total=0; tally={}; direction_counts={}; prior_direction=None; seen_direction_ticks=set()
    for row in rows:
        snap=row['actual']['style'];ref=row['ordinary_snapshot']
        keys(snap,fields,'style snapshot');keys(ref,fields,'reference snapshot')
        keys(snap['diag'],diag_fields,'style diagnostics');keys(ref['diag'],diag_fields-{'direction'},'reference diagnostics')
        need(snap['version']==STYLE_ID['version'] and snap['identity_key']==STYLE_KEY,'unknown live scoring identity')
        exact(snap['direction'],row['style_direction'],'direction live observer/snapshot')
        exact(snap['diag']['direction']['last'],row['style_direction_verdict'],'direction verdict observer/snapshot')
        keys(snap['diag']['direction'],{'last','visited_landings','flight'},'direction detector snapshot')
        for event in row['style_events']:
            strict_event(event);cumulative.append(event);total+=event['points']
            value=tally.setdefault(event['kind'],{'n':0,'points':0});value['n']+=1;value['points']+=event['points']
        exact(snap['recent'],cumulative[-6:],'scored recent snapshot')
        exact(snap['last'],cumulative[-1] if cumulative else {},'scored last snapshot')
        exact(snap['by_kind'],tally,'actual live by-kind')
        need(type(snap['score']) is int and snap['score']==total==row['style_score'],'actual live score includes pending or differs')
        for key in fields-{'version','identity_key','score','direction','recent','last','by_kind','diag'}:
            exact(snap[key],ref[key],'ordinary reference snapshot '+key)
        for key in diag_fields-{'direction','farm_blocked','verdicts'}:
            exact(snap['diag'][key],ref['diag'][key],'ordinary detector live diagnostics '+key)
        for side in (snap,ref):
            need(type(side['diag']['verdicts']) is dict,'detector verdict map')
        exact({k:v for k,v in snap['diag']['verdicts'].items() if k!='direction'},
            {k:v for k,v in ref['diag']['verdicts'].items() if k!='direction'},'ordinary detector verdict counts')
        verdict=snap['diag']['direction']['last']
        need(type(verdict) is dict,'direction verdict object')
        current_tick=row['sample']['tick']
        need(type(current_tick) is int and current_tick>=0,'physical sample tick')
        if verdict:
            reason=verdict.get('verdict')
            need(type(reason) is str and reason in {'stall','facing','ground_dwell','no_motor_jump','flight_timeout','flight_short','travel_short','rise_short','fall_short','efficiency','heading','novelty','eligible'},'unknown direction verdict')
            keys(verdict, {'verdict','tick'} if reason=='stall' else {'verdict','tick','m'},'direction verdict')
            verdict_tick=verdict['tick']
            need(type(verdict_tick) is int and 0<=verdict_tick<=current_tick,'direction verdict tick type/range')
            if reason!='stall':
                measures=verdict['m']
                need(type(measures) is dict,'direction verdict measurements')
                expected={'air_s','track_m','progress_m','rise_m','fall_m','heading_dot','landing_ups'} if reason in {'flight_short','travel_short','rise_short','fall_short','efficiency','heading','novelty','eligible'} else set()
                keys(measures,expected,'direction verdict measurements')
                for value in measures.values():
                    need(type(value) in (int,float) and math.isfinite(value),'finite numeric direction measurement')
            if verdict!=prior_direction:
                need(verdict_tick==current_tick and verdict_tick not in seen_direction_ticks,'new direction verdict must belong to one current physical sample')
                seen_direction_ticks.add(verdict_tick)
                if reason!='stall':direction_counts[reason]=direction_counts.get(reason,0)+1
        else:
            need(prior_direction in (None,{}),'direction verdict erased without attempt reset')
        exact(snap['diag']['verdicts'].get('direction',{}),direction_counts,'independent direction verdict counts')
        prior_direction=copy.deepcopy(verdict)
        for side in (snap,ref):
            count=side['diag']['farm_blocked'].get('direction',0)
            need(type(count) is int and count>=0,'direction anti-farm counter')
        exact({k:v for k,v in snap['diag']['farm_blocked'].items() if k!='direction'},
            {k:v for k,v in ref['diag']['farm_blocked'].items() if k!='direction'},'ordinary anti-farm counters')


def lab_guard(rows):
    counts={};events=[]
    for row in rows:
        experiment=row['motion'].get('experiment',{})
        for key,value in experiment.get('counts',{}).items():counts[key]=max(counts.get(key,0),value)
        for kind in experiment.get('events',[]):
            if kind in ('slide_landing','wall_jump','grapple'):events.append((kind,row['tick'],row['held']))
        if 'jump' in row['motion'].get('events',[]):events.append(('hop',row['tick'],row['held']))
    need(counts.get('wall_jump',0)>=2 and counts.get('slide_landing',0)>=1 and counts.get('grapple',0)>=1,
        'original Lab slide/two wall jumps/grapple missing')
    jumps=[e for e in events if e[0]=='wall_jump']
    need(len(jumps)>=2 and all((e[2].get('move_left') or e[2].get('move_right')) and not e[2].get('move_forward') for e in jumps),
        'Lab wall jump must keep A/D without W')
    chain=[e[0] for e in events]
    need('hop' in chain[chain.index('slide_landing')+1:chain.index('wall_jump')] and
        chain.index('slide_landing')<chain.index('wall_jump')<chain.index('grapple'),'original Lab slide/hop/wall/grapple order')
    return {'ok':True,'counts':counts,'sequence':events}
