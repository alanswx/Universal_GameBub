#!/usr/bin/env python3
"""Compile the actual platform RTL, converting only T80 VHDL for Verilator."""
import subprocess,re,os,signal,argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--games',nargs='+',default=['ladybug']);parser.add_argument('--frames',type=int,default=120);parser.add_argument('--run-only',action='store_true');parser.add_argument('--compile-only',action='store_true');parser.add_argument('--require-audio',action='store_true');args=parser.parse_args()
work=ROOT/'scratch/sim';work.mkdir(parents=True,exist_ok=True)
def run(name,args):
 with (work/(name+'.log')).open('w') as log:
  r=subprocess.run(args,cwd=work,stdout=log,stderr=subprocess.STDOUT)
 if r.returncode:raise SystemExit((work/(name+'.log')).read_text()[-6000:])
 print(name+' passed',flush=True)
if not args.run_only:
 opts=['--std=08','-frelaxed','-fsynopsys','-fexplicit']
 files=[str(ROOT/'rtl/universal/cpu/T80'/f'{n}.vhdl') for n in 'T80_Pack T80_ALU T80_MCode T80_Reg T80 T80pa'.split()]
 files.append(str(ROOT/'rtl/universal/video/mc6845.vhdl'))
 run('ghdl',['ghdl','-a',*opts,*files])
 with (work/'t80.v').open('w') as out,(work/'ghdl_synth.log').open('w') as err:
  subprocess.run(['ghdl','--synth',*opts,'--out=verilog','T80pa'],cwd=work,stdout=out,stderr=err,check=True)
 # Normalize two GHDL escaped aliases only in generated simulation output.
 s=(work/'t80.v').read_text().replace('u0_\\reg ', 'u0_reg_output ').replace('\\reg ', 'reg_output ')
 s=re.sub(r'\bdo\b','do_output',s)
 s=s.replace('module T80pa\n','module T80pa #(parameter Mode=0)\n')
 # GHDL emits reciprocal aliases for some instance outputs. The child drives
 # alu_q directly, so remove its redundant self-driver via alu_n406.
 for lhs,rhs in re.findall(r'^  assign (\w+) = (\w+);',s,re.M):
  if lhs != rhs and re.search(r'^  assign '+re.escape(rhs)+' = '+re.escape(lhs)+r';',s,re.M):
   s=re.sub(r'^  assign '+re.escape(lhs)+' = '+re.escape(rhs)+r';[^\n]*\n','',s,count=1,flags=re.M)
 # Remove redundant alias declarations emitted by GHDL.
 seen=set();lines=[]
 for line in s.splitlines():
  if line.startswith('module '):seen.clear()
  if re.fullmatch(r'  wire .*;',line):
   if line in seen:continue
   seen.add(line)
  if re.match(r'  assign (\w+) = \1;',line):continue
  lines.append(line)
 (work/'t80.v').write_text('\n'.join(lines)+'\n')
 with (work/'mc6845.v').open('w') as out:
  subprocess.run(['ghdl','--synth',*opts,'--out=verilog','mc6845'],cwd=work,stdout=out,check=True)
 # Quiesce only inactive family engines AFTER loading for simulation speed.
 # Their state cannot influence selected outputs; all download memories and
 # shared CPUs retain their real clock. The FPGA uses the original clocks.
 board=(ROOT/'rtl/universal/universal_board.sv').read_text()
 for instance,enable in [('ladybug','variant<=2'),('overlay','variant<=2'),('mrdo_b','mrdo'),('docastle_b','dcastle'),('zerohour_b','zhour'),('cheekyms_b','cheeky'),('cheekyms_snd','cheeky'),('cosmic_b','cosmic')]:
  start=re.search(r'^\w+ '+instance+r'\n',board,re.M).start();end=board.index('\n);',start)+3
  block=board[start:end]
  block,n=re.subn(r'(\.clk(?:_20mhz_i)?\s*\()clk(\))',r'\1clk && (reset || '+enable+r')\2',block)
  assert n==1,instance
  board=board[:start]+block+board[end:]
 (work/'universal_board_sim.sv').write_text(board)
 sv=[ROOT/'rtl/gamebub/game_catalog.sv']+sorted(p for p in (ROOT/'rtl').rglob('*') if p.suffix in ('.sv','.v') and p.name not in ('gb_clocks.sv','game_catalog.sv','universal_board.sv'))
 run('verilator',['verilator','--binary','--timing','-j','8','-O3','-CFLAGS','-O3','-Wno-fatal','-Wno-lint','-Wno-style','-Wno-TIMESCALEMOD','--top-module','tb_universal','--Mdir',str(work/'obj'),str(work/'t80.v'),str(work/'mc6845.v'),str(work/'universal_board_sim.sv'),*[str(p) for p in sv],str(ROOT/'sim/gb_clocks.sv'),str(ROOT/'sim/tb_universal.sv')])
if args.compile_only:raise SystemExit(0)
games=json.loads((ROOT/'gamedb/games.json').read_text())
selected=games if args.games==['all'] else [next(g for g in games if g['key']==key) for key in args.games]
for g in selected:
 command=[str(work/'obj/Vtb_universal'),f"+rom={ROOT/'scratch/roms'/str(g['key']+'.rom')}",f"+key={g['key']}",f"+id={g['id']}",f"+frames={args.frames}"]
 if args.require_audio:command+=['+require_audio']
 tag='game_'+g['key']+'_'+str(args.frames)
 run(tag,command)
 output=(work/(tag+'.log')).read_text()
 assert 'UNIVERSAL PASS' in output,output[-3000:]
 print(output[-1300:],flush=True)
