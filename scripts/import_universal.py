#!/usr/bin/env python3
"""Reproduce the combined Universal dependency import; --check detects edited imports.

Live HEAD was checked 2026-10-15: same as PIN. Refresh deliberately, never
fetch or change submodule revisions from this script.
"""
import argparse, hashlib, json, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT/'upstream/Arcade-Universal_MiSTer'
PIN = '2a8a4515b9f0c796c79da25f8b0c49a1a8eaadaf'
# All board dependencies, excluding platform/Intel IP and undocumented TMS.
FILES = ['rtl/universal_board.sv','rtl/z80_socket.sv'] + [f'rtl/ladybug/{p.name}' for p in sorted((SRC/'rtl/ladybug').glob('*.sv'))] + [str(p.relative_to(SRC)) for family in ('mrdo','docastle','zerohour','cheekyms','cosmic') for p in sorted((SRC/'rtl'/family).glob('*.sv'))] + ['rtl/sound/msm5205.sv','rtl/video/mc6845.vhd'] + [f'rtl/cpu/T80/{n}.vhd' for n in 'T80_Pack T80_ALU T80_MCode T80_Reg T80 T80pa'.split()] + [f'rtl/sound/jt89/hdl/{n}.v' for n in 'jt89 jt89_noise jt89_vol jt89_mixer jt89_tone'.split()]
PATCH=ROOT/'scripts/adaptations/disable_unadvertised_tms.json'

def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=SRC,text=True).strip()==PIN
 records=[]
 for name in FILES:
  data=subprocess.check_output(['git','show',f'{PIN}:{name}'],cwd=SRC)
  assert (SRC/name).read_bytes()==data, f'Dirty upstream source: {name}'
  original=data
  if name=='rtl/universal_board.sv':
   text=data.decode()
   for change in json.loads(PATCH.read_text()):
    assert text.count(change['before'])==1,'Port patch context changed'
    text=text.replace(change['before'],change['after'])
   data=text.encode()
  # Intel RAM is replaced by the separate project module.

  dest=ROOT/'rtl/universal'/Path(name).relative_to('rtl')
  if dest.suffix=='.vhd':dest=dest.with_suffix('.vhdl')
  if a.check: assert dest.read_bytes()==data, f'Edited import: {dest}'
  else: dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
  records.append(dict(source=name,destination=str(dest.relative_to(ROOT)),sha256=hashlib.sha256(original).hexdigest(),imported_sha256=hashlib.sha256(data).hexdigest()))
 manifest=json.dumps(dict(url='https://github.com/RodimusFVC/Arcade-Universal_MiSTer',commit=PIN,live_head_checked='2026-10-15',patches=[dict(path=str(PATCH.relative_to(ROOT)),sha256=hashlib.sha256(PATCH.read_bytes()).hexdigest())],files=records),indent=2)+'\n'
 path=ROOT/'docs/IMPORT_MANIFEST.json'
 if a.check:assert path.read_text()==manifest
 else:path.write_text(manifest)
 print(f'{len(records)} imported dependencies verified')
if __name__=='__main__':main()
