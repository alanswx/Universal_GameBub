# Universal Game Bub handoff

Read PORT_PLAN.md first, then docs/SOURCES.json and
docs/FRAMEWORK_ROTATION_SUMMARY.md. The previous session was explicitly asked
to prepare this folder and stop before port implementation. The next session
should begin implementation when the user resumes the project.

## User requirements

- Port the Universal arcade core from ~/mister/Arcade-Universal_MiSTer to
  Game Bub rev 4 in this separate project. Aim for one combined core with
  game selection by prepared ROM file, following the MCR port's pattern.
- **Use our arcade-capable alanswx/framework fork**, already pinned in
  framework/. It provides opt-in game-layer rotation without extra image RAM.
  It is not upstream gamebub/framework, and not a firmware update.
- **Adapt the existing standalone HTML/JavaScript ROM creator for Universal.**
  People must be able to drop matching MAME ZIPs onto an offline HTML page
  and download the exact format this core expects, plus an SD-folder ZIP.
  The reference implementation is in reference/mcr-rom-builder/.
- Work incrementally: Lady Bug first, then additional boards and games.

## Working rules

Keep the sibling Universal and MCR repos unchanged. Import RTL into rtl/
through a reproducible script with pinned provenance and checked patches.
Do not hand-edit imported source; do not modify upstream submodules to hide
port patches. Verify live upstream HEAD before a new import or refresh;
record new pins deliberately instead of silently switching revisions.

Preserve source copyright/licence notices. No blanket licence is assigned
to the new project. Keep game ROMs, PROM data, samples, build products and
private SD bundles out of commits. MRA recipes and configuration metadata
are allowed; raw game data is not. Use ignored scratch/ for temporary work.
The imported RTL may use scoped macros: audit them; do not blindly apply
MCR's no-macros rule to these different sources.

The framework collects RTL recursively; keep unmodified upstream sources
and reference templates outside rtl/. Rename imported .vhd files to .vhdl
as necessary for framework collection. Replace Intel PLL/RAM IP explicitly.
Use source scripts/env.sh for the installed Vivado/Verilator environment.
Do not push upstream, publish a new repo or release without an instruction
for this new project. Local commits after validated steps are welcome.

Update PORT_PLAN.md with findings and distinguish planned, simulated, routed
and device-tested behavior. User confirmation of MCR hardware does not prove
Universal behavior. Ask only for missing user choices that block useful work.
