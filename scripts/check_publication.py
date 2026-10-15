#!/usr/bin/env python3
"""Audit parent Git history/index and an optional ROM-free release ZIP.

Submodules are pinned links to separately maintained upstream repositories;
this does not audit or republish their independent histories.
"""
import argparse
import hashlib
import re
import subprocess
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = {'.zip', '.rom', '.bin', '.prom', '.wav', '.flac', '.mp3', '.ogg',
             '.nv', '.nvm', '.arc', '.7z', '.rar', '.tar', '.gz', '.bit', '.rbf',
             '.dcp', '.png', '.jpg', '.ppm', '.vcd', '.fst', '.log', '.rpt',
             '.pem', '.key', '.pyc'}
SECRET = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|'
                    rb'\bgh[pousr]_[A-Za-z0-9]{30,}\b|'
                    rb'\bgithub_pat_[A-Za-z0-9_]{40,}\b|'
                    rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', type=Path)
    args = parser.parse_args()
    entries = {}
    for commit in git('rev-list', '--all').decode().splitlines():
        for row in git('ls-tree', '-r', '-z', commit).split(b'\0'):
            if not row:
                continue
            meta, name = row.split(b'\t', 1)
            mode, kind, oid = meta.decode().split()
            entries[(name.decode(), oid)] = mode
    for row in git('ls-files', '--stage', '-z').split(b'\0'):
        if row:
            meta, name = row.split(b'\t', 1)
            mode, oid, stage = meta.decode().split()
            assert stage == '0', 'Unmerged index'
            entries[(name.decode(), oid)] = mode
    blobs = set()
    for (name, oid), mode in entries.items():
        path = PurePosixPath(name)
        assert not ({'scratch', 'build', 'out', '.aws', '.codex', '.agents'} & set(path.parts)), name
        assert path.suffix.lower() not in FORBIDDEN, name
        assert not path.name.startswith('.env'), name
        if mode == '160000':
            assert name in ('framework', 'upstream/Arcade-Universal_MiSTer'), name
            continue
        assert mode in ('100644', '100755'), (name, mode)
        if oid in blobs:
            continue
        data = git('cat-file', 'blob', oid)
        assert len(data) < 2_000_000 and b'\0' not in data, f'Unexpected binary/large blob: {name}'
        data.decode('utf-8')
        assert not SECRET.search(data), f'Potential credential: {name}'
        blobs.add(oid)
    print(f'PASS: {len(blobs)} text blobs across parent history and index; no forbidden artifacts or credential signatures')
    if args.release:
        fixed = {'UNIVERSAL-INSTALL.txt', 'NOTICE.md', 'Universal-ROM-Builder.html',
                 'BUILD-INFO.json', 'supported-games.tsv', 'unavailable-recipes.json', 'SHA256SUMS.txt'}
        core = 'cores/alanswx.Universal/'
        fixed |= {core + n for n in ('Universal-gamebub_rev4.bit', 'core.json', 'files.json', 'settings.json')}
        fixed |= {'licenses/' + p.name for p in (ROOT / 'licenses').glob('*.txt')}
        with zipfile.ZipFile(args.release) as archive:
            names = archive.namelist()
            assert len(names) == len(set(names)) and set(names) == fixed, 'Unexpected release entries'
            assert archive.testzip() is None
            for name in names:
                if not name.endswith('.bit'):
                    assert not SECRET.search(archive.read(name)), f'Potential credential: {name}'
            for line in archive.read('SHA256SUMS.txt').decode().splitlines():
                digest, name = line.split('  ', 1)
                assert hashlib.sha256(archive.read(name)).hexdigest() == digest, name
        print(f'PASS: ROM-free release allowlist, {len(names)} entries, ZIP CRCs and SHA256 manifest')


if __name__ == '__main__':
    main()
