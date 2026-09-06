# python-docling-parse

Programmatic-PDF text and coordinate extraction, at upstream 7.17.0.

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

## Licensing

`license` carries `Apache-2.0` alongside MIT, Zlib, Unlicense, BSD-3-Clause
and BSL-1.0: `package()` installs `PDFIUM-LICENSE`, whose text includes
Apache License 2.0 terms, so omitting the identifier understated what the
package ships.

## Note

This is the only compiled package in the Docling stack here (`arch=('x86_64'
'aarch64')`, CMake plus pybind11, with blend2d, asmjit and loguru vendored).
It is therefore the only one where host tuning from `/etc/makepkg.conf`
reaches a compiler: `-march=znver4 -mtune=znver4 -O3 -flto=auto` was confirmed
in `CMAKE_CXX_FLAGS`, and `MAKEFLAGS` is inherited by the Unix Makefiles
generator (207 objects over a 73 s span, up to 18 completing per second). No
build-flag changes were needed.

`check()` is deliberately untouched: it installs the wheel to a temporary
directory using `installer`'s default bytecode levels, which is already
correct. Only `package()` was changed.

`namcap PKGBUILD` emits `W: Reference to x86_64 should be changed to $CARCH`.
That is a parser false positive on the multi-line `arch=()` array, where the
literal architecture name is required. Do not "fix" it.
