# Universal arcade core → Game Bub port plan

Prepared 2026-10-15. The user asked for this separate project, dependencies
and a plan, then a stop so a fresh LLM can take over. They also explicitly
requested that the next LLM know about our framework for arcade ports and
adapt our HTML ROM creator. **Preparation is complete; implementation has
not started.**

## 1. Inputs and intended result

Target: Game Bub rev 4 (XC7A100T, 135 BRAM36 tiles). Proposed core ID:
`alanswx.Universal`, name `Universal Arcade`. These are proposed names, not
an installed core or reserved firmware identifiers. Aim for a combined core
that recognizes a prepared game image, rather than a separate build per game.

Upstream: https://github.com/RodimusFVC/Arcade-Universal_MiSTer

Verified live default branch `main` HEAD on 2026-10-15:
`2a8a4515b9f0c796c79da25f8b0c49a1a8eaadaf`
(`Refactor Z80's to 2 instances`). The existing sibling checkout was clean
and at this same revision; independent clones were made without hardlinks.
The source submodule here is detached at that pin. Its origin is the public
HTTPS URL, not the sibling directory.

There are 61 MRA recipes covering variants 0–17, including alternatives.
See docs/UPSTREAM_GAMES.tsv. The RTL's variants 18–19 exist but have no MRA
recipes at this revision; leave them unadvertised until researched.

| Variant | Board or family |
|---|---|
| 0 | Lady Bug, Snap Jack, Cosmic Avenger, Dorodon |
| 1–2 | Space Raider and Mrs. Dynamite (8203) |
| 3–6 | Mr. Do! and PAL/bootleg variants |
| 7–8 | Mr. Do's Castle / Do! Run Run family |
| 9 | Indoor Soccer, including ADPCM and twin-stick controls |
| 10–11 | Zero Hour / Red Clash |
| 12 | Cheeky Mouse |
| 13–17 | Space Panic, Cosmic Alien, Magical Spot, Devil Zone, No Man's Land |
| 18–19 | Cosmic Guerilla / Get A Way (TMS99xx); recipe gap at this pin |

## 2. Use our arcade rotation framework

**Do not replace framework/ with stock gamebub/framework.** It is the public
`alanswx/framework` fork, commit
`6e5adf7ed3d8776f504d55e6dbb8d6fcc5cfa930`, on branch
`feature/video-rotation`, based on upstream
`db9d3b0e7989db4a8edc66e47b843097d71f078c`. This is the exact framework
used by the working MCR v0.6.0 release. No new framework work is presumed
necessary for this port.

Read docs/FRAMEWORK_ROTATION_SUMMARY.md and the accompanying patch. The
write-up was copied from the MCR project; its MCR-specific relative links
refer to that original project, whose path is in docs/SOURCES.json.

- Declare optional `videoTransform` using `VideoTransformV0` in the Chisel
  core interface; two-bit clockwise turns are 0, 90, 180, 270 degrees.
- Rotation changes framebuffer **read addressing**, using the existing two
  frame stores. It adds no extra image RAM. Quarter turns fit the picture
  using constant-ratio nearest-pixel scaling. Budget the actual Universal
  framebuffer size and color depth; MCR resource numbers are not this port's.
- The framework handshakes requests across clocks and latches them during
  output blanking at a frame boundary. LCD/HDMI share the game transform.
- The firmware menu retains its normal orientation. `displayRotate` corrects
  panel mounting at build time; do not disable it to rotate a game.
- `0x0108` reports the requested transform, not a writable rotation setting
  or necessarily the currently latched scanout orientation.
- User settings and D-pad remapping belong in the core. Support upright,
  hold-clockwise and hold-counterclockwise grips as in MCR. Derive rotation
  direction from each MRA's flags; do not copy MCR's direction blindly.
- Non-opted-in ColecoVision and IIgs HDL was verified identical to the
  baseline. MCR upright and both sideways grips work on-device. Physical
  HDMI/dock validation and separate routed compatibility builds remain
  outstanding before framework upstream submission. No upstream PR exists.

## 3. Source architecture and important traps

Read `Arcade-Universal.sv`, `rtl/universal_board.sv`, `files.qip` and
`tools/gen_mra.py` in the upstream submodule.

`universal_board` is the natural portable boundary: board clock, reset,
pause, variant/decode/flags, mapped input/DIP bytes, coin inputs, index-0
byte writes, RGB/blank/sync outputs, pixel enable and signed 16-bit audio.
Keep the actual board logic and shared Z80 architecture. Replace the MiSTer
HPS, Intel PLL, video mixer/scaler and high-score wrapper with Game Bub
interfaces. Do not compile the MiSTer top/sys tree as the Game Bub platform.

### ROM/configuration contract

Each MRA supplies **two different streams**. Index 0 is game data at sparse
board addresses; index 1 is a 64-byte hardware/input configuration:

| Bytes | Meaning |
|---|---|
| 0 | Variant |
| 1 | Flags: 4-way, two-frame coin pulses, portrait, ROT90 direction |
| 2 | CPU ROM decode selector |
| 3 | Board-specific flags |
| 4–9 | Idle levels for six input ports |
| 10–15 | Per-port DIP-byte selection; bit 7 means use idle byte |
| 16–63 | Control ID per port bit; a pressed control inverts that bit |

DIP defaults are separate MRA switch metadata. A plain MRA index-0 `.rom`
does **not** carry the index-1 configuration. Preserve all 64 bytes and
DIP defaults in a generated game catalog, selected by full-image CRC32 and
exact size, following MCR's approach. Verify identities are unique across
configurations; if identical data needs distinct configurations, explicitly
resolve that before fixing the converter/file contract. Never guess a variant
from the filename or a short header alone. Do not append configuration bytes
unless both the agreed file format and host loader implement it deliberately.

MRA recipes have `md5="none"`; do not mistake this for a verified digest.
Build reference images from the user's local MAME sets, then record and
verify size/CRC/hash. Include recipe fills, lane mapping and PROM placement.
Unlike MCR, Universal's color/decode PROM data is part of these game layouts;
do not inherit the separate mandatory `ssio.prom` requirement.

**Known source issue:** `Devil Zone.mra` and `Devil Zone (Easier).mra` are not
well-formed XML (parse errors at line 32/31, column 56). Diagnose and record
a narrowly checked text correction in the import/preparation tool; do not
silently skip them or alter the upstream checkout. The inventory was extracted
without executing the upstream generator.

### RAM, timing and memory budget

- `rtl/ram_rom/dpram_dc.vhd` instantiates Intel `altsyncram`. Replace it with
  an inferred/Xilinx-compatible implementation with the same port defaults,
  synchronous-read latency, optional output register and read-during-write
  behavior. Test both ports and actual board consumers before broad imports.
- `rtl/ladybug/crt_flip_fb.sv` contains a 128 KiB RAM used as a flip store,
  also reused for Indoor Soccer sprites and Devil Zone grid data. Framework
  scanout rotation can avoid a second game-flip framebuffer in ordinary
  upright play, but this RAM's alternate ROM/grid uses must be preserved.
  Disabling its output alone does not remove its storage. Synthesize early.
- Many board ROM banks are allocated simultaneously. Budget these plus the
  framework's two frame stores before assuming all boards fit. If required,
  move suitable read-only banks to Game Bub SRAM with a measured scheduler;
  add latency-aware adapters rather than stalling pixel pipelines blindly.
- Upstream uses a 19.656 MHz board clock; the MRA generator documents the
  Lady Bug reference pixel rate as 4.914 MHz and totals 312×262. Verify each
  family's actual totals/enables from RTL and simulation; not all families
  share one raster. Derive legal Xilinx clocks from the 50 MHz board input,
  record any frequency error, and retain the source's fractional enables.
- Define the actual visible raster/crop per family. Do not inherit MCR's
  320×240 crop or its 18-pixel correction. Pipeline blanking and RGB together.
- The existing framework clock constraint relies on the `clk_dpi` name.
  Follow the working Game Bub clock wrappers and constraints.
- Imported VHDL must be collected as `.vhdl`. Audit QIP recursion for T80,
  jt89, mc6845 and TMS dependencies. Audit scoped Verilog macros rather than
  removing definitions without understanding their use.

### Audio and controls

Use signed 16-bit board audio through the normal Game Bub audio path,
with deliberate clock-domain handling, sample timing, volume and DC filtering
as needed. The source contains jt89, MSM5205 and discrete sound models;
inspect what each variant actually uses. Do not assume every board requires
external samples just because upstream includes sample ZIPs. No sample data
was checked out into this project's sparse source working tree.

Reproduce index-1 input maps and polarity, 4-way joystick filtering,
two-frame coin pulses, start/join behavior and DIP defaults. Start with P1
and alternating P2 where practical. Indoor Soccer's twin-stick controls need
a documented handheld mapping. Keep high-score persistence out of the first
bring-up; initialize its unused interface safely.

## 4. Implementation sequence and acceptance checks

1. **Audit/import Lady Bug.** Confirm the pinned source, derive a minimal
   dependency list from files.qip, and create scripts/import_universal.py
   with a provenance manifest and exact checked adaptations. Keep vendor
   IP and unrelated MiSTer modules out of the active RTL tree. Add the RAM
   replacement and test its real latency/port semantics. Estimate full-core
   memory cost and decide whether family gating or SRAM is needed.
2. **Define ROM/configuration and converter together.** Generate Lady Bug's
   index-0 reference and 64-byte config from its MRA using owned local data.
   Establish the catalog and loader contract. Adapt the offline HTML builder
   as described below, rather than making the user depend on CLI tools.
3. **Platform wrapper.** Implement chisel/src/Universal.scala and an RTL
   binding, host download path with backpressure, clocks/reset, safe
   initialization, inputs, video and audio. Suggested metadata core ID is
   alanswx.Universal. Assert reset through config/data writes and clock lock,
   release only for a complete recognized image, and reject damaged/unknown
   images. Ensure game switching fully resets family state.
4. **First boot in simulation.** Use real ROM input through the actual
   Game Bub host protocol and memory model. Check memory contents, CPU boot,
   full-frame raster dimensions, pixel colors, control actions, audio
   activity and reset/reload. Compare against an unmodified upstream board
   simulation or MiSTer/MAME capture. Declare simulation gaps explicitly.
5. **Portrait rotation.** Add the optional framework interface and three
   grip settings with matching controls. Validate asymmetric patterns and
   real game text for direction; prove frame-boundary changes and borders.
6. **First hardware milestone.** Route rev 4, require positive setup/hold
   slack and zero failing endpoints, record resource use, and package a
   clearly identified test. The owner checks Lady Bug picture, coin/start,
   movement, sound and reset. ROM-containing test ZIPs remain private.
7. **Expand by family.** Suggested order: remaining variant-0 games, Mr. Do!,
   8203, Castle/Do! Run Run, then Zero Hour/Red Clash/Cheeky Mouse/Cosmic.
   Add Indoor Soccer after its large sprite/ADPCM and controls are covered.
   Investigate TMS games separately because recipes are absent at this pin.
   Verify source HEAD before each import refresh; do not advertise untested
   variants. Keep one combined core when resource/timing evidence permits.
8. **Finish user-facing packaging.** Metadata/settings, controls guide,
   ROM-free ZIP with offline HTML and README, checksums, and all component
   notices. Public publication is a later user decision for this new project.

## 5. Required offline HTML ROM converter work

**Explicit user request:** modify our HTML ROM creator so it works for this
Universal port. The reference copy is under reference/mcr-rom-builder/; the
original working MCR project must keep working. Adapt reusable ZIP/CRC/UI
code into `web/Universal-ROM-Builder.html`, with maintainable JS/template
sources and a generator/checker under tools/. This file does not exist yet.

- Single self-contained HTML file, opened via file://, offline, no upload,
  server or CDN. Drop one or several MAME ZIPs, match chips by CRC and length,
  support merged/split parent sets, and explain missing chips/wrong revisions.
- Generate recipes/configuration from pinned Universal MRAs and one canonical
  catalog. Parse index-0 assembly and index-1 metadata separately. Support
  only understood MRA operations; reject unsupported operations explicitly.
- Download individual game images and an SD-folder ZIP at
  `roms/Universal/<game>.rom` (or the agreed format), matching the host loader
  exactly. If headerless index-0 is retained, configuration belongs to the
  generated core catalog, not a discarded extra download.
- Remove MCR-only SSIO PROM logic and game listings. Preserve Universal's
  per-game embedded PROM regions and distinct variant/decode/DIP/input data.
- Show only supported/validated games; add families as the core gains support.
  Do not claim all 61 upstream MRAs are playable after the first Lady Bug boot.
- Compare every converted file byte-for-byte to an independent MRA-tool
  output or verified source layout. Test actual browser-native Deflate and
  file-upload UI, plus renamed/missing/corrupt chips, malformed ZIPs, size
  limits, checksums and SD ZIP round trips. Test generated metadata against
  the loader's actual chosen configuration.
- Keep copyrighted input/output bytes in scratch/ only. The generated HTML
  may embed recipes, configuration and checksums, not game/PROM/sample bytes.

## 6. Existing local references and tools

- Working combined arcade port: ../mcr/MCR_GameBub. Read its AGENT/CLAUDE
  instructions only as reference for that project; this project's AGENTS.md
  defines the Universal requirements. Key files: chisel/src/MCR3.scala,
  rtl/gamebub/{mcr3_gamebub,gb_mcr_host,gb_mcr_reset,gb_mcr_video,gb_mcr_audio,
  gb_clocks,gb_sram}.sv, scripts/package.py, sim/ and web/.
- Simpler host/audio/video example: ../adam/ColecoVision_GameBub, especially
  rtl/gamebub/{coleco_gamebub,gb_host,gb_audio,gb_video_out}.sv.
- SDRAM reference if required: ../iigs/Apple-IIgs_GameBub.
- MRA CLI: ../mcr/mra-tools-c/mra. Its output is index 0; index-1 metadata
  must be handled separately. Do not modify the reference tool's source.
- Owned MAME inputs: ~/mister/cardbackup/MiSTer_Data/games/mame/. Read local
  data for testing as needed, but do not copy the collection into the project.
- `source scripts/env.sh`: Vivado 2025.2 and Verilator 5.052 on this host.
  After implementation, the intended build is
  `./mill root.buildCore --target gamebub_rev4`. It is not runnable yet.

## 7. Prepared state / next action

The source and framework pins, sparse source checkout, build launcher,
working rules, converter reference and this plan are present. No Universal
RTL has been imported into the active rtl/ tree; no wrapper, generated game
catalog, working Universal converter, simulation or FPGA build exists yet.
No GitHub project or release was created. A local initial commit records
the handoff.

**First action for the next LLM:** read the pinned Lady Bug MRA, MiSTer input
configuration loader, universal_board ROM map, dual-port RAM implementation
and video timing. Then implement and validate the smallest Lady Bug import
plus the ROM/configuration contract and converter before expanding families.
