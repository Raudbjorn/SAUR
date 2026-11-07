# SAUR

Sveinbjörn's Arch User Repository: reviewed `PKGBUILD` recipes for software I use that is not yet packaged the way I need.

> [!WARNING]
> This is a personal package-source repository, not an official Arch Linux repository and not the Arch User Repository. Read every `PKGBUILD` before building it.

## Packages

| Package | Description | Status |
| --- | --- | --- |
| [`caprine-electron44`](caprine-electron44/) | Caprine (Facebook Messenger) on the system Electron 44 runtime; ~25 MB less installed payload than AUR `caprine` | Buildable; smoke-tested to the login page, logged-in features untested |
| [`detect-it-easy-git`](detect-it-easy-git/) | Detect It Easy file-type identifier (`die`, `diec`, `diel`) built against Qt6 | Buildable; namcap reports only the inherited `/opt` layout and the `qt6-svg` plugin dependency |
| [`docling`](docling/) | Docling CLI and model stack; avoids the `python-typer026` eviction | Buildable; XPU conversion blocked by a transformers fp64 defect, use `--device cpu` |
| [`headroom-git`](headroom-git/) | Full-feature VCS build of Headroom, the LLM context-optimization layer | Buildable with the local `python-installer` bridge and AUR dependencies |
| [`imhex-git`](imhex-git/) | ImHex hex editor from upstream `master` with ImHex-Patterns; offline submodule sources | Buildable; smoke-tested; no clean-chroot build yet |
| [`magika-git`](magika-git/) | VCS build of Google's Magika CLI on the embedded tract runtime; upstream's locked crate graph is required | Buildable; CUDA path not exercised |
| [`okteta-qt6-git`](okteta-qt6-git/) | KDE hex editor, Qt6/KF6 port branch replayed on current `master` | Buildable; upstream port lacks the Structures tool |
| [`omp`](omp/) | Personal fork of oh-my-pi (terminal coding agent), built from a pinned release tag | Recipe verified (source, checksum, metadata); `build()` not yet exercised |
| [`onetbb-git`](onetbb-git/) | oneTBB from a pinned upstream `master` commit with the stateful-allocator `concurrent_queue` patch (PR #1520); replaces the repository `onetbb` | Buildable and installed; 3 queue test binaries pass, full suite not run, no clean-chroot build yet |
| [`photoqt-extensions-git`](photoqt-extensions-git/) | Official PhotoQt extensions from upstream `master`; fixes the AUR recipe's dependency list | Buildable; namcap clean apart from the built-in `PhotoQt` QML module |
| [`photoqt-git`](photoqt-git/) | PhotoQt image viewer from upstream `master`, with Ninja, resvg and OpenSlide | Buildable; launch-tested offscreen, no clean-chroot build yet |
| [`protobuf-c-git`](protobuf-c-git/) | protobuf-c from upstream `next`, patched to build against current protobuf (PR #797) | Buildable; clean-chroot build and `check()` pass against `extra/protobuf` 36.1 |
| [`purple-facebook-git`](purple-facebook-git/) | Facebook Messenger protocol plugin for libpurple 2, tracking upstream `master` | Buildable with AUR `libpurple` and `libgadu`; Facebook login untested |
| [`python-docling`](python-docling/) | Importable Docling library (`docling-slim` upstream), no CLI | Buildable |
| [`python-docling-core`](python-docling-core/) | Docling data types and serialization; `tests/` rename and typer relaxation | Buildable |
| [`python-docling-ibm-models`](python-docling-ibm-models/) | TableFormer and layout models; 4.0.2 is the floor `docling` requires | Buildable |
| [`python-docling-parse`](python-docling-parse/) | Programmatic-PDF extraction; the stack's only compiled package | Buildable |
| [`python-installer`](python-installer/) | Temporary 1.0.1 bridge required to build AUR `python-rapidocr` | Remove after configured repositories ship 1.0.1 or newer |
| [`python-pychromecast-git`](python-pychromecast-git/) | Chromecast client library from upstream `master`; satisfies PhotoQt's `python-pychromecast` dependency | Buildable; import smoke test only, no device tested |
| [`python-semchunk`](python-semchunk/) | Semantic chunking for `docling-core`'s `chunking` extra | Buildable; 4.1.1 exceeds an advisory upstream cap, verified against fixtures |
| [`python-tree-sitter-c`](python-tree-sitter-c/) | `tree_sitter_c` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter-javascript`](python-tree-sitter-javascript/) | `tree_sitter_javascript` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter-language-pack`](python-tree-sitter-language-pack/) | 371 tree-sitter grammars linked into the extension module, with no run-time downloads | Rewritten for upstream 1.x; two upstream grammars are known broken |
| [`python-tree-sitter-python`](python-tree-sitter-python/) | `tree_sitter_python` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter-typescript`](python-tree-sitter-typescript/) | `tree_sitter_typescript` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter025`](python-tree-sitter025/) | `python-tree-sitter` pinned to 0.25.x; 0.26.0 faults on large Solidity inputs | Remove once 0.26.1 or newer passes the reproducer |
| [`searxng-git`](searxng-git/) | SearXNG with a custom theme, BM25 reranking, and Anna's Archive made to actually return results | Builds, installs and runs; theme rebuild adds npm and nodejs to makedepends |
| [`trailmark-git`](trailmark-git/) | Trailmark source-graph parser at upstream `f7e19d3`, plus fork and downstream patches | Buildable with `python-tree-sitter025` and AUR dependencies |
| [`trid`](trid/) | File-type identifier from binary signatures; argument quoting and HTTPS definition updates fixed | Buildable |
| [`xorg-server-git`](xorg-server-git/) | X.Org server from upstream `master` (26.1.99.1; split into server, common, devel, Xephyr, Xnest and Xvfb); driver ABI 28.0/26.0/11.0, so every `xf86-*` driver must be rebuilt | Buildable and installed; Xvfb, Xephyr and Xnest smoke-tested; Xorg itself not yet run on a real VT; no clean-chroot build yet |

## Repository layout

```text
SAUR/
├── docs/
│   ├── packaging-guide.md   # Local packaging and review workflow
│   └── template.PKGBUILD    # Starting point for a new recipe
├── caprine-electron44/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── caprine.sh           # Launcher; @ELECTRON@ substituted in prepare()
│   ├── PKGBUILD             # Electron 44, semver-range dependency refresh
│   └── README.md            # Size reductions, floating deps, smoke test
├── detect-it-easy-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Qt6-pinned VCS build; Ninja, MAKEFLAGS-driven jobs
│   └── README.md            # Qt5/Qt6 dependency mismatch, upstream defects
├── docling/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # CLI recipe; typer/transformers/websockets relaxations
│   ├── README.md            # Eviction blast radius, XPU fp64 defect, workaround
│   └── slim_meta_package.patch
├── headroom-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Package recipe
│   └── README.md            # Package-specific notes
├── imhex-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # master + 18 submodule sources, bundled CLI11, LTO
│   └── README.md            # Deviations from Arch's imhex, CLI11 defect, Not claimed
├── magika-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Rust CLI from upstream main; locked graph, label-suite check()
│   └── README.md            # Name collisions, tract lock pin, host-tuning measurements
├── okteta-qt6-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Port commits cherry-picked onto master in prepare()
│   └── README.md            # Port/master relationship, AUR deltas, upstream gaps
├── omp/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Fork release build; fixed source URL and extracted path
│   └── README.md            # Fork rationale, naming/conflicts, build() not yet run
├── onetbb-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── *.patch              # Stateful-allocator queue patch, applied in prepare()
│   ├── PKGBUILD             # Pinned-commit build; TCM off, pip isolated from live site-packages
│   └── README.md            # Patch provenance, build choices, differences from onetbb
├── photoqt-extensions-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # VCS recipe; dependency fixes (qt6-charts, no exiv2)
│   └── README.md            # Dependency evidence, signature-verification note
├── photoqt-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # VCS recipe; Ninja build, resvg + OpenSlide enabled
│   └── README.md            # Differences from AUR photoqt, namcap false positives
├── protobuf-c-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── *.patch              # Pinned upstream PR #797, skipped once merged
│   ├── PKGBUILD             # `next` branch, soname deps, check() enabled
│   └── README.md            # Why `next`, patch provenance, proto3 optional gap
├── purple-facebook-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # VCS recipe; vendored pidgin tree, no hg, autoreconf in prepare()
│   └── README.md            # Changes from AUR recipe, AUR libpurple/libgadu chain, protoc-c pitfall
├── python-docling/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Library-only recipe, bytecode-level fix
│   └── README.md            # Distribution renamed to docling-slim upstream
├── python-docling-core/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # tests/ rename, parallel check(), typer relaxation
│   └── README.md            # Bytecode measurements and typer deviation
├── python-docling-ibm-models/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Bytecode fix, unversioned transformers dependency
│   └── README.md            # Why 4.0.2 is the floor; transformers 5.13 hazard
├── python-docling-parse/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── *.patch              # Upstream build patches, applied in prepare()
│   ├── CHROMIUM-LICENSE     # Vendored-source license, referenced by source()
│   ├── PDFIUM-LICENSE       # Vendored-source license, referenced by source()
│   ├── PKGBUILD             # Compiled recipe; host tuning verified, unchanged
│   └── README.md            # Host-tuning evidence and namcap false positive
├── python-installer/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Temporary repository-version bridge
│   └── README.md            # Removal condition and build notes
├── python-pychromecast-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # VCS recipe; requests dependency, build-cap skip
│   └── README.md            # Differences from extra and AUR, upstream deprecations
├── python-semchunk/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── package_test.py      # check() helper, referenced by source()
│   ├── PKGBUILD             # Bytecode-level fix
│   └── README.md            # Why 4.1.1 exceeds the advisory upstream cap
├── python-tree-sitter-c/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Bytecode-level fix
│   └── README.md            # Why the language pack does not substitute
├── python-tree-sitter-javascript/    # same three files as -c
├── python-tree-sitter-language-pack/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Static-grammar, offline build of upstream 1.x
│   └── README.md            # Link mode, host tuning, known upstream defects
├── python-tree-sitter-python/        # same three files as -c
├── python-tree-sitter-typescript/    # same three files as -c
├── python-tree-sitter025/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Version-pinned binding, provides python-tree-sitter
│   └── README.md            # Fault description and removal condition
├── trailmark-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── *.patch              # Fork + downstream patches, applied in prepare()
│   ├── PKGBUILD             # Package recipe
│   └── README.md            # Patch provenance and host-tuning caveats
├── trid/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # HTTPS sources; prepare() switches definition updates to HTTPS
│   ├── README.md            # Fixes from the AUR recipe, StringZilla benchmark
│   ├── trid.install         # Post-install definitions-update hint
│   ├── trid.sh              # /usr/bin/trid wrapper
│   └── update-trid-defs.*   # Updater script, systemd service and weekly timer
└── xorg-server-git/
    ├── .SRCINFO             # Generated AUR metadata
    ├── PKGBUILD             # Six-package split; ABI provides checked against source in prepare()
    ├── README.md            # Driver ABI coupling, build notes, verification limits
    ├── xorg-server-git.install  # Post-install logind note
    └── xvfb-run*            # Wrapper script and man page (Fedora lineage)
```

Upstream source checkouts used during package research are deliberately ignored. `makepkg` obtains its own source under the package's `src/` directory.

## Build and install

Install `base-devel` and Git first:

```bash
sudo pacman -S --needed base-devel git
```

The workflow below also requires an installed and configured `paru`; pacman
cannot resolve packages from AUR.

Clone this repository and inspect both recipes. Install the local bridge first,
verify its versioned dependency, and only then let paru resolve Headroom's AUR
dependency graph:

```bash
git clone https://github.com/Raudbjorn/SAUR.git &&
  cd SAUR &&
  less python-installer/PKGBUILD &&
  less headroom-git/PKGBUILD &&
  (
    cd python-installer &&
      makepkg -si --needed --force
  ) &&
  pacman -T 'python-installer>=1.0.1' &&
  paru -Bi ./headroom-git
```

`pacman -T` must print nothing. Do not collapse these stages into
`paru -Bi ./python-installer ./headroom-git`: paru can build the bridge without
installing it before evaluating AUR `python-rapidocr`. Plain `makepkg -s`
delegates dependency installation to pacman, which cannot resolve AUR packages.

Never run `makepkg` as root.

## Update a VCS package

A `-git` package resolves the current upstream revision while building. From
the SAUR repository root, refresh it with:

```bash
git pull --ff-only &&
  pacman -T 'python-installer>=1.0.1' &&
  paru -Bi ./headroom-git
```

If `pacman -T` reports the bridge as missing, repeat the initial bridge
installation above before rebuilding Headroom.

When maintaining a recipe, regenerate `.SRCINFO` after every metadata change:

```bash
makepkg --printsrcinfo > .SRCINFO
```

## Validation policy

A recipe is not ready merely because Bash accepts it. Before publication:

```bash
bash -n PKGBUILD
makepkg --verifysource
makepkg --cleanbuild --clean --force
namcap PKGBUILD
namcap ./*.pkg.tar.*
```

Clean-chroot builds with `pkgctl build` remain the stronger dependency check. See the [packaging guide](docs/packaging-guide.md) for the complete workflow and authoritative Arch references.

## Contributing

Keep changes package-scoped, use HTTPS sources, pin integrity with checksums or signed VCS history where possible, declare direct dependencies rather than relying on transitive ones, and never hand-edit `.SRCINFO`.

Package sources in this repository are provided under [0BSD](LICENSE). Upstream software retains its own license.
