#!/usr/bin/env python3
"""Generate the self-contained Universal offline ROM builder."""
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
 recipes=json.loads((ROOT/'gamedb/games.json').read_text())
 template=(ROOT/'web/rom-builder.template.html').read_text()
 script=(ROOT/'web/rom-builder.js').read_text()
 data=template.replace('/* RECIPES */','const RECIPES='+json.dumps(recipes,separators=(',',':'))+';').replace('/* SCRIPT */',script)
 out=ROOT/'web/Universal-ROM-Builder.html'
 if args.check:assert out.read_text()==data,'Stale builder'
 else:out.write_text(data)
 print('Universal ROM builder verified' if args.check else 'Universal ROM builder generated')
if __name__=='__main__':main()
