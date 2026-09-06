# SAUR

Sveinbjörn's Arch User Repository: reviewed `PKGBUILD` recipes for software I use that is not yet packaged the way I need.

> [!WARNING]
> This is a personal package-source repository, not an official Arch Linux repository and not the Arch User Repository. Read every `PKGBUILD` before building it.

## Packages

| Package | Description | Status |
| --- | --- | --- |
| [`docling`](docling/) | Docling CLI and model stack; avoids the `python-typer026` eviction | Buildable; XPU conversion blocked by a transformers fp64 defect, use `--device cpu` |
| [`headroom-git`](headroom-git/) | Full-feature VCS build of Headroom, the LLM context-optimization layer | Buildable with the local `python-installer` bridge and AUR dependencies |
| [`omp`](omp/) | Personal fork of oh-my-pi (terminal coding agent), built from a pinned release tag | Recipe verified (source, checksum, metadata); `build()` not yet exercised |
| [`python-docling`](python-docling/) | Importable Docling library (`docling-slim` upstream), no CLI | Buildable |
| [`python-docling-core`](python-docling-core/) | Docling data types and serialization; `tests/` rename and typer relaxation | Buildable |
| [`python-docling-ibm-models`](python-docling-ibm-models/) | TableFormer and layout models; 4.0.2 is the floor `docling` requires | Buildable |
| [`python-docling-parse`](python-docling-parse/) | Programmatic-PDF extraction; the stack's only compiled package | Buildable |
| [`python-installer`](python-installer/) | Temporary 1.0.1 bridge required to build AUR `python-rapidocr` | Remove after configured repositories ship 1.0.1 or newer |
| [`python-semchunk`](python-semchunk/) | Semantic chunking for `docling-core`'s `chunking` extra | Buildable; 4.1.1 exceeds an advisory upstream cap, verified against fixtures |
| [`python-tree-sitter-c`](python-tree-sitter-c/) | `tree_sitter_c` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter-javascript`](python-tree-sitter-javascript/) | `tree_sitter_javascript` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter-language-pack`](python-tree-sitter-language-pack/) | 371 tree-sitter grammars linked into the extension module, with no run-time downloads | Rewritten for upstream 1.x; two upstream grammars are known broken |
| [`python-tree-sitter-python`](python-tree-sitter-python/) | `tree_sitter_python` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter-typescript`](python-tree-sitter-typescript/) | `tree_sitter_typescript` grammar module for code-aware chunking | Buildable |
| [`python-tree-sitter025`](python-tree-sitter025/) | `python-tree-sitter` pinned to 0.25.x; 0.26.0 faults on large Solidity inputs | Remove once 0.26.1 or newer passes the reproducer |
| [`trailmark-git`](trailmark-git/) | Trailmark source-graph parser at upstream `f7e19d3`, plus fork and downstream patches | Buildable with `python-tree-sitter025` and AUR dependencies |

## Repository layout

```text
SAUR/
├── docs/
│   ├── packaging-guide.md   # Local packaging and review workflow
│   └── template.PKGBUILD    # Starting point for a new recipe
├── docling/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # CLI recipe; typer/transformers/websockets relaxations
│   ├── README.md            # Eviction blast radius, XPU fp64 defect, workaround
│   └── slim_meta_package.patch
├── headroom-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Package recipe
│   └── README.md            # Package-specific notes
├── omp/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Fork release build; fixed source URL and extracted path
│   └── README.md            # Fork rationale, naming/conflicts, build() not yet run
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
└── trailmark-git/
    ├── .SRCINFO             # Generated AUR metadata
    ├── *.patch              # Fork + downstream patches, applied in prepare()
    ├── PKGBUILD             # Package recipe
    └── README.md            # Patch provenance and host-tuning caveats
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
