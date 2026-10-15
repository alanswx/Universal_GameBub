#!/usr/bin/env python3
"""Check bounded firmware metadata fields before making an SD-card bundle.

Limits: Game Bub reference-metadata and firmware origin/v1.1-beta info.rs.
ArrayString capacities count UTF-8 bytes, not Python Unicode characters.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def bounded(value,limit,path):
 if not isinstance(value,str) or len(value.encode('utf-8'))>limit:
  raise ValueError(f'{path}: must be a string of at most {limit} UTF-8 bytes')
def validate(core,files,settings):
 for name in ('id','name','author'):bounded(core['metadata'][name],32,'metadata.'+name)
 for name,limit in (('version',16),('url',64),('license',32)):
  if core['metadata'].get(name) is not None:bounded(core['metadata'][name],limit,'metadata.'+name)
 for bit in core['bitstreams']:
  bounded(bit['target'],16,'bitstreams.target');bounded(bit['filename'],32,'bitstreams.filename')
 if len(files['files'])>8:raise ValueError('At most 8 file slots')
 for f in files['files']:
  bounded(f['label'],16,'files.label')
  if f.get('filename') is not None:bounded(f['filename'],32,'files.filename')
  if len(f.get('extensions',[]))>4:raise ValueError('At most 4 extensions per file')
  for ext in f.get('extensions',[]):bounded(ext,8,'files.extensions')
 if len(settings['settings'])>16:raise ValueError('At most 16 settings')
 for setting in settings['settings']:
  if setting['type']=='list' and len(setting['items'])>8:raise ValueError('At most 8 list items')
def check():
 validate(*(json.loads((ROOT/'metadata'/name).read_text()) for name in ('core.json','files.json','settings.json')))
 print('Firmware metadata bounds: PASS')
if __name__=='__main__':check()
