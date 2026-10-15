#!/usr/bin/env python3
"""Record routed resources, source fingerprints and actual simulation results."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 build=ROOT/'build/Universal-gamebub_rev4';runs=build/'Universal-gamebub_rev4.runs/impl_1'
 timing=(runs/'top_handheld_timing_summary_routed.rpt').read_text()
 assert 'All user specified timing constraints are met.' in timing
 header=timing.index('WNS(ns)');match=re.search(r'\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)',timing[header:])
 assert match
 util=(runs/'top_handheld_utilization_placed.rpt').read_text()
 def resource(name):return float(re.search(r'\| '+re.escape(name)+r'\s*\|\s*([\d.,]+)',util)[1].replace(',',''))
 games=json.loads((ROOT/'gamedb/games.json').read_text());results={}
 pattern=re.compile(r'GAME PASS (\w+) variant=(\d+) frames=(\d+) writes=(\d+) fetches=(\d+) colored=(\d+) audio=(\d+)')
 for path in (ROOT/'scratch/sim').glob('game_*.log'):
  text=path.read_text(errors='replace')
  for m in pattern.finditer(text):
   key=m[1]
   if f'UNIVERSAL PASS {key}:' not in text[m.end():]:continue
   result=dict(zip(('variant','frames','writes','m1_address_changes','colored_pixels_total','nonzero_audio_cycles'),map(int,m.groups()[1:])))
   if key not in results or result['frames']>results[key]['frames']:results[key]=result
 known={g['key'] for g in games};results={k:v for k,v in results.items() if k in known}
 assert len(results)==len(games),f'Simulation incomplete: {sorted(known-set(results))}'
 browser=(ROOT/'scratch/combined-browser-final.log').read_text();assert 'BROWSER PASS: 57' in browser
 assert 'INPUT PASS: all 57' in (ROOT/'scratch/inputs-result.log').read_text()
 paths=[p for folder in ('rtl','chisel/src') for p in (ROOT/folder).rglob('*') if p.is_file()]+[ROOT/'build.mill']
 pins=json.loads((ROOT/'docs/SOURCES.json').read_text())
 report=dict(target='gamebub_rev4',core_id='alanswx.Universal',version=json.loads((ROOT/'metadata/core.json').read_text())['metadata']['version'],universal_pin=pins['universal']['commit'],framework_pin=pins['framework']['commit'],tool='Vivado 2025.2',timing=dict(setup_wns_ns=float(match[1]),hold_whs_ns=float(match[5]),setup_failing_endpoints=int(match[3]),hold_failing_endpoints=int(match[7]),coverage_warning='Inherited framework audioClock and external I/O timing coverage warnings; see PORT_PLAN.md'),resources=dict(LUTs=int(resource('Slice LUTs')),FFs=int(resource('Slice Registers')),BRAM36_tiles=resource('Block RAM Tile'),BRAM36_available=135,DSPs=int(resource('DSPs'))),bitstream_sha256=hashlib.sha256((build/'Universal-gamebub_rev4.bit').read_bytes()).hexdigest(),source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)},device_tested=True,device_confirmed_combined=dict(game="Mr. Do!",version="0.2.0-test1",owner_report="mr do played",exact_set=None,sound_confirmed=False),device_confirmed_baseline=dict(game='ladybug',version='0.1.0-test2',owner_report='works very well; sound works'),validation=dict(ROM_images='57 independent MRA CLI byte comparisons pass',offline_builder='57 Node and Chrome native Deflate/SHA, file uploads, SD ZIP button/path/CRC round trips pass',input_maps='57 idle/DIP defaults; two-frame coin impulse, focus filtering and Soccer twin-stick/P2-start tests pass',simulation_model='Actual platform and board RTL; T80/mc6845 converted by GHDL; simulation-only quiescing of inactive family engines; FPGA retains original clocks'),simulation_results=results,gaps=['New families require on-device gameplay and sound validation','Most games have short bootstrap/raster checks; colored/audio counts do not prove full gameplay','No independent MAME/upstream full-frame comparison','Physical HDMI/dock and each grip remain to be tested','Four missing-data alternative MRAs excluded explicitly','TMS variants 18/19 have no pinned recipes and are not enabled'])
 assert report['timing']['setup_failing_endpoints']==report['timing']['hold_failing_endpoints']==0
 (ROOT/'docs/BUILD_TEST_RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 (ROOT/'gamedb/supported-games.tsv').write_text('set\tname\tvariant\tportrait\tsimulation_frames\tdevice_confirmation\n'+''.join(f"{g['key']}\t{g['name']}\t{g['variant']}\t{bool(g['config'][1]&16)}\t{results[g['key']]['frames']}\t{'test2 baseline picture/sound' if g['key']=='ladybug' else 'pending'}\n" for g in games))
 print(f"Recorded {len(results)} games; WNS={match[1]}, WHS={match[5]}; BRAM={report['resources']['BRAM36_tiles']}")
if __name__=='__main__':main()
