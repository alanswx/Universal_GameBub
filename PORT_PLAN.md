# Universal arcade core → Game Bub port plan

Prepared 2026-10-15. The user asked for this separate project, dependencies
and a plan, then a stop so a fresh LLM can take over. They also explicitly
requested that the next LLM know about our framework for arcade ports and
adapt our HTML ROM creator. **Historical preparation snapshot; see section 8 for the implemented Lady Bug baseline.**

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

## 7. Handoff state / next action

Lady Bug test2 is owner-confirmed, including sound. The combined expansion
now enables 57 sets across all 22 main games represented by pinned MRAs.
See sections 8–9 and docs/BUILD_TEST_RESULT.json for exact validation and gaps.
The next step is owner gameplay/sound testing of the new families. Four
missing-data alternatives and the undocumented TMS boards remain excluded.
Public repository/release publication is now requested; see section 10.

## 8. Lady Bug implementation — 2026-10-15

The first rev 4 hardware-test bitstream now exists. This does not establish
on-device Universal support; owner testing is still required.

### Implemented

- `scripts/import_universal.py` imports 32 dependencies from the original pin,
  with source SHA256s in `docs/IMPORT_MANIFEST.json`; `--check` detects edits.
  Live public HEAD was rechecked on 2026-10-15 and remains the pinned commit.
  Imported source bytes are checked against pinned Git blobs and unchanged;
  VHDL filenames become `.vhdl`. No `define/undef/include` macros occur in
  this Lady Bug dependency subset; later families still need scoped audits.
- The first binding instantiates upstream `ladybug_machine` and shared T80pa
  directly, mirroring the variant-0 portion of `universal_board`. It imports
  the required inactive 8203 submodule dependency but enables only Lady Bug.
  No other families, Intel PLL/RAM, MiSTer wrappers or CRT flip store are
  active. A future combined core still needs measured family memory gating.
- `dpram_dc.sv` replaces Intel RAM. It preserves synchronous read latency,
  write-first own-port reads, default inactive inputs and byte enables, zero
  initialization and the original wrapper's actual use of outdata_reg_a on
  both outputs. Mixed-port same-address read/write is unspecified; callers
  must avoid simultaneous writes to one address. No init-file use is supported.
- MMCM: 50 MHz * 20 = 1000 MHz VCO; /50.875 = 19.656019656 MHz board clock
  (+1 ppm), /35 = 28.571428 MHz LCD, /5 = 200 MHz SPI. `clk_dpi` retained.
- Stored raster is 240x192, 2 bits/channel, 312x262 total, pixel CE /4. The
  source DAC codes are preserved; framework 2-bit expansion approximates the
  analog resistor weights with 0/85/170/255 rather than 0/81/174/255.
- Same system domain for host, RAM and machine; framework handles LCD/HDMI
  and audio CDC. Signed 16-bit mono, selectable saturated gain, muted in menu.
- ROM format remains exact MRA index 0 (no header/config trailer): Lady Bug
  World, 49248 bytes, CRC32 3b3bfa7e, SHA256
  1f537ada7b9bc68fb82de77aa23381b26b37f79a0b70cfcd4e3cbccfeb0b41f5.
  Full 64-byte index-1 config and DF/FF DIP defaults are preserved in the
  canonical generated catalog. Only this image is recognized. Host tracks
  sequential writes, drains posted writes before commands, checks size/CRC,
  and holds reset on unknown/damaged/incomplete files.
- Offline `web/Universal-ROM-Builder.html` adapts our MCR ZIP/CRC/UI code;
  maintainable JS/template and generator/checker are included. Matches CRC
  plus chip length, preserves embedded PROM regions, exports individual ROM
  or `roms/Universal/Lady Bug.rom` in an SD-folder ZIP. No SSIO PROM requirement.
- P1 and alternating P2, Select coin, Start P1, R P2; generated input polarity
  and 4-way filtering. Lady Bug uses held coins (its MRA does not request the
  two-frame impulse flag). No high-score saving. Grip rotation requests are
  270/180/0 degrees clockwise for upright/CW/CCW, derived from Lady Bug ROT270;
  D-pad follows grip. Configuration changes are not exposed as arbitrary DIPs.

### Verified so far

- Independent `mra-tools-c` index-0 output matches the generated ROM byte for
  byte. Catalog and offline builder reproducibility checks pass.
- Node checks: byte-identical conversion, renamed/missing/corrupt/wrong-length
  chips, malformed/encrypted/unsupported/oversized/ZIP64/truncated ZIPs, and
  SD ZIP round trips. Headless Chrome passes actual native Deflate/CRC/SHA
  and file-upload UI, offline via file://.
- Portable RAM test passes zero init, both ports, synchronous read/write-first
  behavior, byte lanes and optional additional output register.
- Platform simulation loads real ROM through HostV0, rejects a corrupt image,
  compares program and graphics RAM bytes, checks default DIP/input polarity
  and all three rotation requests. Frames measure 240x192; captured text is
  upright after ROT270 and the game reaches ROM OK / RAM OK. The corrected six-second
  run passes coin interrupt/start and signed audio activity, reaching the
  PART 1 / GOOD LUCK screen, then halt and recognized-image reload. The
  original 5 ms test press was below the source chute filter threshold of
  470000 clocks (about 24 ms); a realistic 50 ms press passes. Captures remain
  in ignored scratch/sim. Actual maze movement remains a hardware check;
  this simulation checks its port mapping rather than player displacement.
- First Vivado 2025.2 rev 4 route: 4655 LUTs, 3275 FFs, 43.5/135 BRAM tiles,
  zero DSPs; WNS +0.265 ns, WHS +0.032 ns, zero setup/hold failing endpoints.
  All user-specified timing constraints pass. The framework still reports
  40 no-clock pins under its generated `audioClock` and 46 unconstrained
  internal endpoints, plus external I/O delay warnings; these are a timing
  coverage limitation, not proof that every path is constrained.
- Framework and upstream submodules, sibling MCR repository remain unchanged.

### Remaining and test artifacts

- Extended boot/coin/start/audio/halt/reload simulation is complete and passes.
- No independent upstream-board/MAME frame comparison yet. The simulation
  converts T80 with GHDL and normalizes generated alias artifacts; Vivado
  builds the original VHDL. MMCM and physical LCD/HDMI/audio are not simulated.
- Test on the actual rev 4: orientation/text/borders, all directions, coin/P1/P2,
  sound, menu/resume, Reset, reload, all grips. No Universal device test yet.
- `python3 scripts/package.py --private` makes the local owned-ROM test ZIP;
  without the flag it makes a ROM-free test ZIP. Both are ignored build output,
  require passing routed timing and refuse a bitstream older than its sources.
  See `docs/TEST_INSTALL.txt`. No public repository/release/push is authorized.
- Expand remaining variant-0 games only after this baseline is confirmed.
  Other families, multi-config identity collisions, Devil Zone XML correction,
  alternate RAM/grid uses, twin-stick mapping and SRAM scheduling remain planned.

### Test2 packaging correction — owner launch report

The owner reports test1 stays in or returns to the menu when Run Core is
pressed. `metadata/files.json` used the 24-byte label `Universal ROM (Lady Bug)`,
but the firmware `CoreFile.label` is `ArrayString<16>`. The v1.1-beta source
parses files.json in `get_core` and aborts launch on a deserialize error,
before FPGA programming. Official reference-metadata confirms the 16-character
limit: https://docs.gamebub.net/developing-cores/reference-metadata/ .

Test2 changes this label to `Universal ROM` (13 bytes) and adds
`scripts/check_metadata.py`, called by packaging, to enforce bounded fields
using UTF-8 byte counts. A regression check rejects the actual test1 bundle's
metadata and accepts test2. The routed bitstream and ROM bytes are unchanged;
no new synthesis, route or gameplay simulation is needed for this metadata fix.
The first bundle's RTL simulation did not exercise firmware JSON parsing;
that was a validation gap. Test2 launch on hardware is not yet confirmed.

The small `build/Universal-LadyBug-test2-metadata-fix.zip` replaces only core.json
and files.json under cores/alanswx.Universal; full test2 bundles are also built.

## 9. Combined-game expansion in progress

Owner confirms test2 Lady Bug works very well and sound works on the Game Bub.
This establishes Lady Bug picture/gameplay/sound hardware confirmation only;
it does not confirm HDMI, the other grips or newly added families.

Live upstream HEAD rechecked before expansion: still
2a8a4515b9f0c796c79da25f8b0c49a1a8eaadaf. Framework pin remains unchanged.
All families represented by pinned MRAs are being integrated via universal_board,
with 57 distinct images assembled from owned local collections and independently
byte-compared with mra-tools-c. Four alternatives lack matching chips; see
`docs/UNAVAILABLE_RECIPES.json`. No data is downloaded. The extra owned local
reference directory is ~/Downloads/mame-merged/mame-merged.

The checked source adaptations disable the undocumented TMS18/19 boundary,
which has no recipes. Full original notices are preserved. The AST macros in
Zero Hour, Cheeky Mouse, Magical Spot and No Man's Land are scoped and undefined
at each file end; retained deliberately. Devil Zone's two malformed XML
attributes receive an exact checked `&` to `&amp;` correction outside upstream.
No upstream submodule or sibling repository is modified.

The builder supports verified offset/length ROM slices, CRC+length matching,
merged parents, and SD ZIP exports. Node checks and native Chrome Deflate/SHA
and upload UI tests pass for all 57 images. No image identity collisions found.

The combined source raster is centered in a fixed 256x192 frame using two small
line buffers. 240-wide families get 8-pixel side borders; 256-wide families
retain the whole raster. RGB is 3 bits per channel. Lady Bug now shares this
canvas and may appear slightly smaller than the first 240x192 build. Source
board clocks/enables and game sound cadence are retained. Output refresh uses
the baseline framePeriod; Cosmic/Cheeky native 352x262 / 5.408 MHz differs from
Lady Bug's 312x262 / 4.914 MHz, so framebuffer repeats/drops may occur.

Initial combined synthesis fits: 135/135 BRAM tiles, about 39k LUTs, 66 DSPs.
The tool maps the framework overlay to distributed RAM to fit. Routing and
full-board simulation remain in progress; these are not yet acceptance results.

### Integration findings

The initial 135-BRAM route failed on direct system-clock to display-clock
arcs through the framework menu after Vivado spilled that memory to LUT RAM.
No timing exceptions were added to hide this. `dpram_dc` now infers LUT RAM
for tiny memories with address width <=9 (palette PROMs and line stores),
retaining synchronous latency and read/write behavior. This frees BRAM so
the menu remains block RAM. Revised route: WNS +0.233 ns, WHS +0.014 ns,
zero failing setup/hold endpoints. A final build also includes the separately
validated exclusive Indoor Soccer Start+R mapping; its results supersede this
intermediate route once recorded.

All 57 input/DIP defaults, two-frame coin pulses, focus gating, Soccer twin
stick/fire and exclusive P2 start pass `sim/tb_inputs.sv`. A six-second
combined-board Lady Bug regression passes boot/coin/start/audio/halt/reload.
Every catalog image is receiving a short bootstrap/raster/reload simulation,
with longer family captures recorded separately. Simulations convert T80 and
mc6845 VHDL with GHDL. To keep simulation practical only, unselected family
engines are quiesced after download; all download RAM and shared CPU clocks
continue. FPGA source clocks remain unchanged. This model is not physical
MMCM/HDMI/LCD validation, and short runs do not establish full playability.

SD output filenames are derived from the pinned MRA filenames rather than
unsanitized titles; this avoids the question mark in Cosmic Alien's early
version title, which FAT cannot use. Native browser tests now actually click
SD ZIP export and verify every path and CRC. ZIP output is flattened before
Blob creation to avoid recursive Blob-reader overflow on large catalogs in
older Node/browser runtimes.

### Final combined route and short-run results

The final 0.2.0-test1 route passes: WNS +0.291 ns, WHS +0.039 ns, zero
setup/hold failing endpoints; 31341 LUTs, 13489 FFs, 132.5/135 BRAM tiles,
66/240 DSPs. Inherited framework audioClock/external I/O timing coverage
warnings remain; no new exceptions were added. This supersedes the intermediate
+0.233/+0.014 route above. FPGA and ROM bytes in the staged 57-set test ZIP are
final, with validation reports included in the packaged archives.

All 57 images pass real HostV0 download, full CRC/size identity, corrupted-image
rejection, CPU activity, complete 256x192 capture, all grip requests, halt and
same-image reload in the combined model. Every image matches independent
mra-tools-c output byte for byte. The browser-native and input-map tests pass.
Twenty selected games also pass 60-frame boot checks, and Lady Bug and Mr. Lo!
pass 361-frame runs with audio activity. Read the per-set frame/audio/color
counts in BUILD_TEST_RESULT.json rather than treating the
short-run success marker as proof of full playability. Mr. Lo! performs an
extended memory clear before showing a picture; its one-second blank capture
is not by itself a failed boot. The longer run reaches visible output.

The test ZIP is build/Universal-57-games-rev4-private-test.zip; a ROM-free
counterpart includes the offline builder and install instructions. Packaging
checks firmware metadata bounds, source fingerprints and bitstream/report
identity, plus every private ROM's size/CRC/SHA and ZIP round trips. The owner subsequently confirmed "mr do played" on this combined build.
This establishes Mr. Do! gameplay only; exact set, sound, HDMI and additional
games remain unconfirmed.

## 10. Public repository and release

The owner explicitly requested a public alanswx repository, push and release,
superseding earlier preparation-only restrictions. Publish source, metadata,
notices and the ROM-free 0.2.0-test1 bundle only. Keep all raw ROM/PROM/sample
data, captures, local build trees and private SD ZIPs excluded. The release
uses the already routed bitstream; no hardware source changes were made.
Mr. Do! gameplay is now owner-confirmed; its exact set and audio were not
specified. Remaining families need hardware gameplay/sound testing.

Publication audit: parent Git history and staged source contain text sources,
recipes, metadata and pinned submodule links only. The release has an explicit
14-file allowlist with ZIP CRC and SHA256 manifest checks. No raw ROMs/PROMs,
samples, screenshots, private ZIPs or credentials are included. Imported RTL
and extracted original notices retain upstream whitespace intentionally.
