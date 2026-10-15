#!/usr/bin/env python3
"""Compare every catalog image with an independent MRA CLI assembly."""
import json,subprocess,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 games=json.loads((ROOT/'gamedb/games.json').read_text())
 tool=ROOT.parent/'mcr/mra-tools-c/mra'
 dirs=[Path.home()/'Downloads/mame-merged/mame-merged',Path.home()/'mister/cardbackup/MiSTer_Data/games/mame']
 for g in games:
  out=ROOT/'scratch/roms'/f"{g['key']}-independent.rom"
  cmd=[str(tool)]
  for d in dirs:cmd+=['-z',str(d)]
  result=subprocess.run(cmd+['-o',str(out),str(ROOT/g['mra'])],capture_output=True,text=True)
  if result.returncode or not out.is_file():raise RuntimeError(g['key']+': '+result.stdout+result.stderr)
  data=out.read_bytes()
  assert data==(ROOT/'scratch/roms'/f"{g['key']}.rom").read_bytes(),g['key']
  assert hashlib.sha256(data).hexdigest()==g['sha256']
 print(f'MRA CLI PASS: {len(games)} images byte-identical, including sliced ROMs and corrected Devil Zone XML')
if __name__=='__main__':main()
