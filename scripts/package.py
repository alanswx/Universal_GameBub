#!/usr/bin/env python3
"""Package the routed rev 4 test: ROM-free by default, --private includes owned ROM."""
import argparse,hashlib,json,zipfile,zlib
from pathlib import Path
from check_metadata import check as check_metadata
ROOT=Path(__file__).resolve().parents[1]
def main():
 check_metadata()
 p=argparse.ArgumentParser();p.add_argument('--private',action='store_true');a=p.parse_args()
 build=ROOT/'build/Universal-gamebub_rev4';bit=build/'Universal-gamebub_rev4.bit'
 assert bit.is_file(),'Build rev4 first'
 sources=[*ROOT.glob('rtl/**/*'),*ROOT.glob('chisel/src/**/*'),ROOT/'build.mill',*ROOT.glob('framework/src/**/*.scala'),*ROOT.glob('framework/verilog/**/*'),ROOT/'framework/package.mill',ROOT/'framework/scripts/build_core.py']
 assert not any(s.is_file() and s.stat().st_mtime>bit.stat().st_mtime for s in sources),'Rebuild: bitstream older than source'
 timing=build/'Universal-gamebub_rev4.runs/impl_1/top_handheld_timing_summary_routed.rpt'
 assert 'All user specified timing constraints are met.' in timing.read_text(),'Routed timing must pass'
 report=json.loads((ROOT/'docs/BUILD_TEST_RESULT.json').read_text())
 assert report['version']==json.loads((ROOT/'metadata/core.json').read_text())['metadata']['version'],'Record this build before packaging'
 assert hashlib.sha256(bit.read_bytes()).hexdigest()==report['bitstream_sha256'],'Build report/bitstream mismatch'
 for name,digest in report['source_sha256'].items():
  assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,'Build report/source mismatch: '+name

 entries=[(bit,'cores/alanswx.Universal/'+bit.name)]
 entries += [(ROOT/'metadata'/n,'cores/alanswx.Universal/'+n) for n in ('core.json','files.json','settings.json')]
 entries += [(ROOT/'docs/TEST_INSTALL.txt','UNIVERSAL-INSTALL.txt'),(ROOT/'docs/NOTICE.md','NOTICE.md'),(ROOT/'web/Universal-ROM-Builder.html','Universal-ROM-Builder.html')]
 entries += [(ROOT/'docs/BUILD_TEST_RESULT.json','BUILD-INFO.json'),(ROOT/'gamedb/supported-games.tsv','supported-games.tsv'),(ROOT/'docs/UNAVAILABLE_RECIPES.json','unavailable-recipes.json')]
 entries += [(f,'licenses/'+f.name) for f in sorted((ROOT/'licenses').glob('*.txt'))]
 if a.private:
  for g in json.loads((ROOT/'gamedb/games.json').read_text()):
   path=ROOT/'scratch/roms'/f"{g['key']}.rom";data=path.read_bytes()
   assert len(data)==g['size'] and f'{zlib.crc32(data):08x}'==g['crc32']
   assert hashlib.sha256(data).hexdigest()==g['sha256']
   entries.append((path,f"roms/Universal/{g['rom_filename']}"))
 out=ROOT/'build'/('Universal-57-games-rev4-private-test.zip' if a.private else 'Universal-57-games-rev4-ROM-free-test.zip')
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
  for path,name in entries:z.write(path,name)
  z.writestr('SHA256SUMS.txt',''.join(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {name}\n' for path,name in entries))
 with zipfile.ZipFile(out) as z:
  assert z.testzip() is None
  assert set(z.namelist())=={n for _,n in entries}|{'SHA256SUMS.txt'}
  for path,name in entries:assert z.read(name)==path.read_bytes()
 print(out)
 print(hashlib.sha256(out.read_bytes()).hexdigest())
if __name__=='__main__':main()
