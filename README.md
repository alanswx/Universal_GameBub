# Universal Arcade for Game Bub rev 4

Combined hardware-test core with **57 ROM-set recipes across 22 main games**.
Lady Bug test2 is owner-confirmed, including sound. Mr. Do! gameplay is
owner-confirmed on the combined build; its exact set and sound were not
specified. Other games require hardware testing; bootstrap simulations are
not complete playability checks. See [PORT_PLAN.md](PORT_PLAN.md) section 9 for scope and
[BUILD_TEST_RESULT.json](docs/BUILD_TEST_RESULT.json) for measured results.

Download the ROM-free ZIP from [Releases](https://github.com/alanswx/Universal_GameBub/releases)
and extract it at the SD-card root, replacing `cores/alanswx.Universal`.
Open the included offline ROM builder, supply your own matching MAME ZIPs,
then export and extract its SD-folder ZIP. Launch Universal Arcade and choose
a prepared image under `roms/Universal`. Read the [controls/install instructions](docs/TEST_INSTALL.txt).
The existing Lady Bug ROM format is unchanged. No firmware update is needed.

The self-contained [offline ROM builder](web/Universal-ROM-Builder.html)
accepts matching MAME ZIPs, including merged/split parents, and exports individual
ROM images or an SD-folder ZIP. Configuration and DIP defaults are selected by
exact full-image size/CRC in the core. No game bytes are embedded in the page.
Four alternative sets lack matching local chips and are explicitly listed in
[unavailable recipes](docs/UNAVAILABLE_RECIPES.json). TMS18/19 have no pinned
recipes and are not enabled.

Clone with `git clone --recurse-submodules https://github.com/alanswx/Universal_GameBub.git`.
The pinned upstream checkout contains third-party project history; ROMs and
samples from that repository are not release assets of this port.

Build: `source scripts/env.sh`, then
`./mill root.buildCore --target gamebub_rev4`.
Package: `python3 scripts/package.py --private` (owned-ROM private bundle),
or omit `--private` for the ROM-free test bundle.

Validation entry points:

- `python3 scripts/import_universal.py --check`
- `python3 tools/generate_catalog.py --check` (owned local MAME inputs)
- `python3 tools/check_mra_images.py` (independent MRA CLI comparison)
- `python3 tools/check_rom_builder.py --browser` (Node and Chrome, offline)
- `python3 scripts/check_metadata.py`
- `source scripts/env.sh`, then `python3 sim/run.py --games all --frames 16`
- `python3 sim/run.py --run-only --games ladybug --frames 361 --require-audio`

The simulator converts original T80 and mc6845 VHDL using GHDL; inactive family
engines are quiesced only in simulation for speed. FPGA sources retain their
original board clocks. RAM inference puts tiny PROMs/line stores in LUT RAM so
the framework's dual-clock menu framebuffer retains block RAM.

Use the pinned **alanswx/framework arcade rotation fork**, unchanged. Provenance
is in [SOURCES.json](docs/SOURCES.json) and [IMPORT_MANIFEST.json](docs/IMPORT_MANIFEST.json).
Component licences and full source headers are under `licenses/`; no blanket
project licence is assigned. ROMs, private ZIPs and build products stay ignored.
