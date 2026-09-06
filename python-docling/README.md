# python-docling

The importable Docling library (`docling-slim` upstream), at 2.125.0, without
CLI entry points or the heavy model stack. See [`docling`](../docling/) for
the command-line interface.

## Why this exists

The AUR recipe passes `--compile-bytecode 2` to `python -m installer`. That
option is argparse `action="append"`, so passing only `2` **replaces** the
`[0, 1]` default rather than adding to it: the package ships `.opt-2.pyc` and
no plain `.pyc`, and ordinary non-`-OO` imports find no cached bytecode under
read-only `/usr/lib`, recompiling on every interpreter start. This recipe
ships the Arch-standard levels 0 and 1. Nothing else is changed.

## Build

```bash
makepkg -si --needed --force
```

## Removal condition

This is a defect fix, not a preference. It should go upstream to the AUR
recipe rather than be dropped here.

## Distribution name

Upstream renamed the distribution to `docling-slim`; the import name is still
`docling`. `importlib.metadata.version("docling")` raises
`PackageNotFoundError` — query `docling-slim` instead.
