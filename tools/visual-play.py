#!/usr/bin/env python3
"""send ordinary inputs to the native exploration fixture; show only player-visible telemetry."""
import argparse,json,time,uuid
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--inbox',type=Path,required=True)
parser.add_argument('--keys',nargs='*',default=[])
parser.add_argument('--seconds',type=float,default=.5)
parser.add_argument('--mouse',type=float,nargs=2,default=[0,0],metavar=('DX','DY'))
parser.add_argument('--restart',action='store_true')
parser.add_argument('--practice',action='store_true')
parser.add_argument('--quit',action='store_true')
parser.add_argument('--note',default='')
args=parser.parse_args()
aliases={'w':'move_forward','s':'move_back','a':'move_left','d':'move_right','space':'jump','ctrl':'crouch','c':'crouch'}
allowed=set(aliases.values())
keys=[aliases.get(x,x) for x in args.keys]
if not set(keys)<=allowed:parser.error('keys must be w a s d space ctrl or their action names')
if not 0<args.seconds<=3:parser.error('seconds must be greater than zero and at most3')
ident=uuid.uuid4().hex[:10]
request={'id':ident,'keys':keys,'frames':max(1,round(args.seconds*30)),'mouse':args.mouse,'restart':args.restart,'practice':args.practice,'quit':args.quit,'note':args.note}
args.inbox.mkdir(parents=True,exist_ok=True)
assert not (args.inbox/'request.json').exists(),'another command is pending'
temp=args.inbox/'request.json.tmp';temp.write_text(json.dumps(request));temp.replace(args.inbox/'request.json')
if args.quit:
 print('quit input requested');raise SystemExit()
response=args.inbox/'response.json'
end=time.monotonic()+60
while time.monotonic()<end:
 if response.exists():
  result=json.loads(response.read_text())
  if result.get('id')==ident:
   print(json.dumps({k:result[k] for k in ['id','image','speed','mode','finished','finish_kind','respawns','stage','elapsed']},indent=2));break
 time.sleep(.1)
else:raise SystemExit('native game did not acknowledge within60seconds')
