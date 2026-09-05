# python-tree-sitter-c

The tree-sitter C grammar as an importable `tree_sitter_c` module.
Required by `docling-core`'s `chunking` extra for code-aware chunking.

Note that [`python-tree-sitter-language-pack`](../python-tree-sitter-language-pack/)
does **not** substitute for this: it installs a single
`tree_sitter_language_pack` module and does not expose per-language modules
under the names `docling-core` imports.

## Why this exists

The AUR recipe passes `--compile-bytecode 2` to `python -m installer`. That
option is argparse `action="append"`, so passing only `2` **replaces** the
`[0, 1]` default rather than adding to it: the package ships `.opt-2.pyc` and
no plain `.pyc`, and ordinary non-`-OO` imports find no cached bytecode under
read-only `/usr/lib`, recompiling on every interpreter start. This recipe
ships the Arch-standard levels 0 and 1. Nothing else is changed.

## Dependencies

This grammar declares language **ABI 15**, so `depends` carries
`python-tree-sitter>=0.25.0` rather than an unversioned binding: an older
binding raises `ValueError` when the grammar loads. The floor is per-grammar
and reflects what the built module actually declares, read back with
`Language(...).abi_version`.

The native `tree-sitter` library is **not** a runtime dependency and was
removed from `depends`. The extension module links none of it — `ldd` on the
installed `.so` reports zero `libtree-sitter` entries; it uses Python's C API
and hands back a grammar capsule.

## Build

```bash
makepkg -si --needed --force
```

## Removal condition

This is a defect fix, not a preference. It should go upstream to the AUR
recipe rather than be dropped here.

## Not verified

`namcap PKGBUILD` emits `W: Reference to x86_64 should be changed to $CARCH`.
That is a parser false positive on the multi-line `arch=()` array, where the
literal architecture name is required. Do not "fix" it.
