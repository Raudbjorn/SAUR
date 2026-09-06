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
dependency, so the AUR recipe's `python-transformers>=5.4.0` and
`python-websockets>=14.0` fail dependency resolution despite both being
installed and above the floor (transformers 5.13.0.dev0, websockets
16.1.dev18).

Note that `>=5.4.0` is the AUR recipe's own floor. Upstream v2.125.0 requires
`transformers>=4.42.0,<6.0.0`, and it is upstream's floor that the conflict
below encodes.

Both are unversioned here. The `-git` packages are left alone: replacing them
is a system-wide decision this recipe has no business making.

Unversioning drops upstream's ceilings along with its floors, so the ceilings
are restored as versioned conflicts — upstream caps `transformers <6.0.0`
(and excludes 5.13.0 on Linux) and `websockets <17.0`:

```bash
conflicts=(
  'python-transformers=5.13.0'
  'python-transformers<4.42.0'
  'python-transformers>=6.0.0'
)
```

A versioned conflict does not match an unversioned provide, so these constrain
only real versioned providers. Verified with `pacman -U --print`, which
resolves cleanly with both `-git` packages installed.

> [!NOTE]
> `python-websockets` deliberately gets **no** conflicts entry, though upstream
> caps it at `<17.0`. It is only a `checkdepend` and an `optdepend` here, never
> a hard dependency, so a conflict would block installation entirely over a
> feature the user may never touch. Its supported range lives in the optdepend
> description instead. `python-transformers` is a hard dependency, so bounding
> that one with conflicts is proportionate.

The two `optdepends` whose providers declare bare provides — `python-transformers`
here and `python-websockets` — are likewise unversioned, with the floor kept as
prose in the description. `optdepends` never block an install, but pacman does
report whether each is satisfied, and a versioned entry is reported unsatisfied
against a bare provide: it told users the feature was unavailable when it was
not. `pacman -Qi docling` now shows
`python-websockets: remote Docling service streaming (14.0 or newer) [installed]`.

## Local model dependencies

`depends` carries upstream's full `models-local` extra rather than leaning on
what `python-docling-ibm-models` happens to pull in: `python-accelerate` and
`python-huggingface-hub` are declared directly alongside `python-pytorch`,
`python-torchvision`, `python-docling-ibm-models` and `python-defusedxml`.
Docling passes `device_map` to Transformers, which requires Accelerate, and
imports `huggingface_hub` directly in `models/utils/hf_model_download.py`.

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
