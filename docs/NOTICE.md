# Source notices

This project does not assign a blanket licence to its dependencies.
The Universal core credits Rodimus and its component authors, including the
Lady Bug implementation by Arnim Laeuger, T80 and jt89. Preserve their exact
source notices when importing and packaging. The framework has its own
LICENSE; this project pins the modified alanswx rotation fork. The converter
reference and build helpers originate from alanswx/MCR_GameBub as recorded
in SOURCES.json. No game ROMs, PROM data or external sound samples are tracked in the
parent repository. Owned local ROM bytes exist only in ignored scratch/build
outputs for private testing. Exact component headers and licences accompany
test packaging under licenses/. The host/clock adapters derive from the MCR
and ColecoVision Game Bub adapters (GPL-3.0-or-later). Upstream's sparse checkout excludes its
sample/archive and release-bitstream working files; its independent Git
history remains the upstream repository's history.

The MC6845 component includes a noncommercial redistribution condition; see
its preserved notice in rtl/universal/video/mc6845.vhdl and
licenses/Universal-component-notices.txt. This public source/release carries
those component conditions and makes no blanket project licence claim.
