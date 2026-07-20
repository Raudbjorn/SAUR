# `headroom-git`

Arch VCS package for [Headroom](https://github.com/headroomlabs-ai/headroom), the Python/Rust context-optimization layer for LLM applications.

This recipe tracks upstream `main` and installs the feature set represented by upstream's `headroom-ai[all]` extra, subject to upstream's Python-version markers: proxy/API support, AST-aware compression, local ML compression, memory, relevance scoring, image/OCR handling, reports, OpenTelemetry, evaluation helpers, voice support, HTML ingestion, MCP tools, and spreadsheets.

## Name collision

Two unrelated projects use the name Headroom:

- `headroom-ai` in AUR is the stable package for this LLM project;
- `headroom` in AUR is a Haskell license-header manager.

Both install `/usr/bin/headroom`. Consequently this recipe:

```bash
provides=("headroom-ai=$pkgver")
conflicts=('headroom-ai' 'headroom')
```

It deliberately does **not** provide `headroom`.

## Dependencies

The full feature set is substantial. Official Arch repositories provide most dependencies, including PyTorch, ONNX Runtime, FastAPI, OpenAI, MCP, and OpenTelemetry packages. Several dependencies currently come from AUR, notably:

- `python-anthropic`
- `python-fastembed`
- `python-magika`
- `python-rapidocr`
- `python-sentence-transformers`
- `python-sentencepiece`
- `python-sqlite-vec`
- `python-tokenizers`
- `python-trafilatura`
- `python-transformers`
- `python-tree-sitter`
- `python-tree-sitter-language-pack`

Arch currently ships Python 3.14. Upstream restricts LiteLLM to Python versions below 3.14, so this package correctly omits `litellm`; Headroom's token accounting works, but LiteLLM-backed model pricing and dollar-savings estimates are unavailable. Users who require that integration need an isolated Python 3.13 installation rather than forcing an incompatible system dependency.

Plain `makepkg -s` cannot build missing AUR dependencies. The current Arch
repository also provides `python-installer` 1.0.0 while AUR `python-rapidocr`
requires 1.0.1. From the SAUR repository root, install the local bridge first
and then let paru resolve this package:

These commands require an installed and configured `paru`.

```bash
(
  cd python-installer &&
    makepkg -si --needed --force
) &&
  pacman -T 'python-installer>=1.0.1' &&
  paru -Bi ./headroom-git
```

`pacman -T` must print nothing. A single
`paru -Bi ./python-installer ./headroom-git` invocation is not equivalent:
paru may build the bridge without activating it before checking RapidOCR.

Upstream excludes the compromised PyPI distribution `ast-grep-cli==0.44.1`; that wheel shipped an info-stealer. This recipe depends on Arch's native Rust `ast-grep` package instead and does not install the affected PyPI wheel.

## Build internals

Review `PKGBUILD` before running the repository-root commands above. Once all
declared dependencies are installed, plain `makepkg -si` also works from this
directory.

`pkgver()` combines upstream's declared version with the Git revision count and abbreviated commit. Rebuilding later resolves the latest `main` revision automatically.

The package uses upstream's locked Cargo graph and a source-local Cargo cache. Maturin produces one wheel containing the Python package and the compiled `headroom/_core` extension; `python-installer` installs that wheel beneath pacman's package root.

## Validate

```bash
bash -n PKGBUILD
makepkg --verifysource
makepkg --printsrcinfo > .SRCINFO
makepkg --cleanbuild --clean --force
namcap PKGBUILD
namcap ./*.pkg.tar.*
```

After installation:

```bash
headroom --version
python -c 'import headroom, headroom._core; print(headroom.__file__)'
```

## Update

Because this is a VCS package, no manual source checksum changes are needed:

```bash
git pull --ff-only
makepkg -Csi
```

Regenerate `.SRCINFO` whenever recipe metadata changes.

## Scope

This repository packages Headroom but is not affiliated with its upstream maintainers. Report packaging defects here; report application defects to [upstream issues](https://github.com/headroomlabs-ai/headroom/issues).
