# MCR converter reference snapshot

Copied from MCR_GameBub commit a47b413. This is the existing **MCR** converter,
not a working Universal converter. Its generated HTML is self-contained; the
generator/checker still contain MCR-specific paths, SSIO PROM handling and
recipes. Adapt these into this project's web/ and tools/ during implementation.
The original MCR project must continue to work unchanged.

The generator needs upstream MRA descriptions; not all of its MCR dependencies
are copied here. Use the original project for its full working regression.
No ROM, PROM or sample bytes are included in this reference snapshot.
