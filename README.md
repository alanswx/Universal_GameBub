# Universal arcade core for Game Bub

Preparation and handoff project for porting RodimusFVC's Arcade-Universal_MiSTer
to **Game Bub rev 4**. No Game Bub core has been implemented or built yet.

**Start with [PORT_PLAN.md](PORT_PLAN.md).** It contains the inspected source
architecture, the implementation sequence, validation requirements and the
next session's first task. See [AGENTS.md](AGENTS.md) for working rules.

## Dependencies already present

- `upstream/Arcade-Universal_MiSTer`: pinned upstream source and MRA recipes,
  with a sparse working tree excluding supplied samples and release bitstreams.
- `framework`: **our alanswx/framework arcade rotation fork**, pinned to
  `6e5adf7ed3d8776f504d55e6dbb8d6fcc5cfa930`. Use this fork for the port.
- `reference/mcr-rom-builder`: existing MCR HTML converter source, generator
  and checks to adapt for Universal. These remain reference files for now.
- `mill`, `.mill-opts`, `build.mill`, `scripts/env.sh`: build preparation.
  The declared `Universal` core class does not exist yet; build commands
  become usable after the wrapper is implemented.

The framework changes are explained in
[docs/FRAMEWORK_ROTATION_SUMMARY.md](docs/FRAMEWORK_ROTATION_SUMMARY.md).
Exact pins and reference locations are recorded in [docs/SOURCES.json](docs/SOURCES.json).

The upstream inventory contains 61 MRA descriptions covering variants 0–17.
The RTL also declares variants 18–19, whose MRA recipes are absent at this pin.
Do not equate upstream declarations with working Game Bub support.

## Next session

Open this directory directly and ask the next LLM to read AGENTS.md and
PORT_PLAN.md, then begin with the Lady Bug baseline. The requested deliverable
also includes adapting our offline HTML ROM converter to Universal.

No public repository, release, FPGA build or ROM bundle was created for this
project. The local repository has an initial handoff commit.
