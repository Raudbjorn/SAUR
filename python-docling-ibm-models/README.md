# python-docling-ibm-models

TableFormer and layout models used by Docling, at upstream 4.0.2.

## Why this exists

Two changes over the AUR recipe.

### `--compile-bytecode 2` ships no usable bytecode

Same defect as [`python-docling-core`](../python-docling-core/): passing only
`2` to `python -m installer`'s argparse `action="append"` option replaces the
`[0, 1]` default instead of adding to it, so ordinary non-`-OO` imports find
no cached bytecode under read-only `/usr/lib`. This recipe ships levels 0 and
1 (25 modules each).

### `python-transformers` cannot be a versioned dependency here

`python-transformers-git` declares a bare, unversioned
`Provides: python-transformers`. pacman will not match an unversioned provide
against a versioned dependency, so the AUR recipe's
`python-transformers>=4.42.0` fails **both** `makepkg`'s dependency check and
`pacman -U`, even though transformers 5.13.0.dev0 is installed and sits well
inside upstream's `>=4.42.0,<6.0.0` range.

The dependency is therefore unversioned in this recipe. Note the asymmetry:
`python-pytorch-opt-xpu` declares `Provides: python-pytorch=2.13.0` — properly
versioned — so `python-pytorch>=2.2.2` resolves without help.

Unversioning the dependency drops upstream's `<6.0.0` ceiling as well as its
floor, which would otherwise let a Transformers 6.x package satisfy it and
fail at runtime. The ceiling is restored as a versioned conflict:

```bash
conflicts=(
  'python-transformers=5.13.0'
  'python-transformers<4.42.0'
  'python-transformers>=6.0.0'
)
```

A versioned conflict does not match an unversioned provide either, so this
constrains only a real versioned provider and leaves `python-transformers-git`
alone. Verified with `pacman -U --print`, which resolves cleanly with
`python-transformers-git` installed. The `=5.13.0` entry is unchanged and
still guards against a real versioned 5.13.0.

## Why 4.0.2 specifically

This is not a cosmetic bump. `docling` 2.126.0 requires
`docling-ibm-models>=4.0.2,<5`; at 3.14.0 the top-level package is
uninstallable.

## Build

```bash
makepkg -si --needed --force
```

## Removal conditions

- The bytecode change is a defect fix and should go upstream.
- Restore `python-transformers>=4.42.0` once `python-transformers-git`
  declares a versioned provide, or once a versioned `python-transformers` is
  the installed provider.

## Not verified

`check()` runs four upstream test files (19 tests, offline). The transformers
5.13.0 hazard upstream documents — huggingface/transformers#47148, where
`AutoImageProcessor.register()` breaks on a string `config_class` — was
reproduced directly against the installed build and is **not** present. It is
also moot for this package, which registers through `AutoConfig.register` and
`AutoModel.register` (`tableformer_v2/model.py:936-937`), both of which run
cleanly at import.

The OpenCV `optdepend` carries upstream's ceiling, written as `<5` rather
than as a literal transliteration of upstream's `<5.0.0.0`.

> [!WARNING]
> PEP 440 treats `5.0.0` and `5.0.0.0` as **equal**, so `<5.0.0.0` excludes
> 5.0.0. pacman's `vercmp` ranks them by segment count, so it reports
> `5.0.0 < 5.0.0.0` and a literal `<5.0.0.0` would admit the very version
> upstream excludes. Confirmed with `vercmp 5.0.0 5.0.0.0` (returns `-1`) and
> observed directly: with the literal bound, `pacman -Qi` marked the
> `optdepend` `[installed]` against `python-opencv` 5.0.0. Do not transliterate
> PEP 440 bounds into pacman constraints without checking `vercmp`.

Arch's `python-opencv` is 5.x and no packaged provider of that name is in
range (`opencv4` provides nothing, `python-opencv-git` declares no provides),
so the `optdepend` correctly reports unsatisfied. `check()` passes regardless;
the legacy TableFormer image-preprocessing path was never exercised.
