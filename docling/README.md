# docling

The Docling command-line interface and its model dependencies, at upstream
2.125.0. The importable library is packaged separately as
[`python-docling`](../python-docling/); this recipe adds the CLI entry points
(`docling`, `docling-tools`) and the heavy model stack.

## Why this exists

Three dependency deviations, all forced by what is installed on this host.
`package()` already used `installer`'s default bytecode levels and is
unchanged.

### `python-typer026` would evict `python-typer`

The AUR recipe depends on `python-typer026>=0.12.5` to satisfy upstream's
`typer>=0.12.5,<0.27.0`. `python-typer026` declares
`Conflicts: python-typer`, so installing it removes `python-typer`.

> [!WARNING]
> Reverse dependencies of `python-typer` observed on this host:
> `python-mcp`, `python-spacy` (and `python-spacy-en_core_web_lg`),
> `python-transformers-git` (and `python-optimum`, `python-optimum-intel`,
> `python-optimum-onnx`, `python-peft`, `python-sentence-transformers`,
> `python-surya-ocr`), `python-weasel`, and `video-match-finder-git`.
> Check `pactree -r python-typer` on your own host.

This recipe depends on `python-typer>=0.12.5`. The cap is advisory and the
proof is this package's own tests: the 17 CLI cases in `check()`, including
`test_cli_help`, `test_cli_version` and `test_cli_convert_help`, pass on the
installed typer 0.27.2.

### Unversioned provides: `python-transformers`, `python-websockets`

`python-transformers-git` and `python-websockets-git` both declare bare,
unversioned provides. pacman will not match those against a versioned
dependency, so `python-transformers>=5.4.0` and `python-websockets>=14.0`
fail dependency resolution despite both being installed and above the floor
(transformers 5.13.0.dev0, websockets 16.1.dev18).

Both are unversioned here. The `-git` packages are left alone: replacing them
is a system-wide decision this recipe has no business making.

## Build

```bash
makepkg -si --needed --force &&
  pacman -T python-typer
```

`pacman -T` must print nothing — if it reports `python-typer` missing, the
eviction described above has happened and other packages are already broken.

## Distribution name

Upstream renamed the distribution to `docling-slim` (the import name is still
`docling`). `importlib.metadata.version("docling")` therefore raises
`PackageNotFoundError`; query `docling-slim` instead.

## Removal conditions

- Restore `python-typer026` only if it stops declaring
  `Conflicts: python-typer`; otherwise drop the relaxation when upstream lifts
  the `<0.27.0` cap.
- Restore the versioned `python-transformers` and `python-websockets`
  dependencies once the installed providers declare versioned provides.

## Known defect on Intel Arc (XPU)

Conversion on the XPU device fails:

```text
RuntimeError: Required aspect fp64 is not supported on the device
  transformers/models/rt_detr_v2/modeling_rt_detr_v2.py:988
  build_2d_sinusoidal_position_embedding
```

`build_2d_sinusoidal_position_embedding` constructs a `float64` tensor on the
device. An Arc A770 cannot represent fp64; `torch.arange(4,
dtype=torch.float64, device='xpu')` raises the same error directly.

This is the bug docling's own `pyproject.toml` documents for Apple MPS —
*"transformers 5.9.0-5.15.x crash on MPS: `build_2d_sinusoidal_position_embedding`
builds float64 tensors on-device … Fixed in 5.16.0"* — but upstream scopes the
exclusion to `sys_platform == "darwin"`, so it is not excluded for XPU. The
installed transformers is 5.13.0.dev0.

Workaround, verified:

```bash
docling --device cpu --to md --output . document.pdf
```

The real fix is transformers 5.16.0 or newer.

## Not verified

`--device cpu` was verified on one trivial generated PDF, not on real
documents. The XPU failure was observed once; whether only the layout model is
affected or the whole pipeline was not determined.

`check()` runs 17 curated CLI tests, not the full upstream suite.
