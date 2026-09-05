# python-docling-core

Docling's data-type and serialization core, at upstream 2.95.0.

## Why this exists

The AUR recipe is sound but lags upstream and carries two defects that matter
on this host.

### `--compile-bytecode 2` ships no usable bytecode

`python -m installer`'s `--compile-bytecode` is an argparse `action="append"`
option. Passing only `2` therefore **replaces** the `[0, 1]` default rather
than adding to it, so the package ships `.opt-2.pyc` and no plain `.pyc`.
Ordinary (non `-OO`) imports then find no cached bytecode under a read-only
`/usr/lib` and recompile every module on every interpreter start, unable to
write the cache.

Measured on the installed 2.92.0 package built from the unmodified AUR recipe:

| | plain `.pyc` | `.opt-1.pyc` | `.opt-2.pyc` |
| --- | --- | --- | --- |
| AUR recipe | **0** | 0 | 105 |
| This recipe | **105** | 105 | 0 |

This recipe passes `--compile-bytecode 0 --compile-bytecode 1`, the levels
Arch's own Python packages ship.

### Upstream renamed `test/` to `tests/` in 2.95.0

The AUR `check()` hardcodes twelve `test/...` paths and fails outright on this
version. All twelve files and all four referenced node IDs still exist under
the new directory name; they are simply repointed here.

`check()` additionally runs under `pytest-xdist` (`-n auto`). The suite is
pure Python and CPU-bound, so it is the only part of this package that scales
with core count: 96 tests in 4.4 s on 24 threads.

## Deviation from the AUR recipe: `python-typer`

Upstream caps `typer <0.27.0`. The AUR recipe satisfies that with
`python-typer026`, which declares `Conflicts: python-typer`. Installing it
evicts `python-typer` system-wide.

> [!WARNING]
> Reverse dependencies of `python-typer` observed on this host:
> `python-mcp`, `python-spacy` (and `python-spacy-en_core_web_lg`),
> `python-transformers-git` (and `python-optimum`, `python-optimum-intel`,
> `python-optimum-onnx`, `python-peft`, `python-sentence-transformers`,
> `python-surya-ocr`), `python-weasel`, and `video-match-finder-git`.
> Check `pactree -r python-typer` on your own host.

This recipe depends on `python-typer>=0.12.5` instead. Arch does not enforce
upper bounds and Python does not enforce them at import. Verified rather than
assumed: both console scripts render correctly on the installed typer 0.27.2.

```bash
docling-view --help && docling-serialize --help
```

## Build

```bash
makepkg -si --needed --force
```

## Removal conditions

- The bytecode change is a defect fix, not a preference. It should go upstream
  to the AUR recipe rather than be dropped.
- The `tests/` paths become the AUR recipe's own once it moves past 2.94.1.
- Drop the `python-typer` relaxation once either upstream lifts the `<0.27.0`
  cap or `python-typer026` stops declaring `Conflicts: python-typer`.

## Not verified

Both console scripts and the 96-test `check()` subset pass on typer 0.27.2.
That is not proof that no code path in docling-core touches typer API removed
in 0.27 — only that nothing exercised here does.

`check()` runs a curated subset. The full suite needs optional extras; see
[`python-semchunk`](../python-semchunk/) and the `python-tree-sitter-*`
grammars in this repository for the `chunking` extra.

`namcap PKGBUILD` is clean. Four sibling recipes here emit
`W: Reference to x86_64 should be changed to $CARCH`; that is a namcap parser
false positive on a multi-line `arch=()` array, where the literal architecture
name is required. Do not "fix" it.
