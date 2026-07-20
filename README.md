# SAUR

Sveinbjörn's Arch User Repository: reviewed `PKGBUILD` recipes for software I use that is not yet packaged the way I need.

> [!WARNING]
> This is a personal package-source repository, not an official Arch Linux repository and not the Arch User Repository. Read every `PKGBUILD` before building it.

## Packages

| Package | Description | Status |
| --- | --- | --- |
| [`headroom-git`](headroom-git/) | Full-feature VCS build of Headroom, the LLM context-optimization layer | Buildable; several runtime dependencies come from AUR |

## Repository layout

```text
SAUR/
├── docs/
│   ├── packaging-guide.md   # Local packaging and review workflow
│   └── template.PKGBUILD    # Starting point for a new recipe
└── headroom-git/
    ├── .SRCINFO             # Generated AUR metadata
    ├── PKGBUILD             # Package recipe
    └── README.md            # Package-specific notes
```

Upstream source checkouts used during package research are deliberately ignored. `makepkg` obtains its own source under the package's `src/` directory.

## Build and install

Install `base-devel` and Git first:

```bash
sudo pacman -S --needed base-devel git
```

Clone this repository, inspect the recipe, then build from the package directory:

```bash
git clone https://github.com/Raudbjorn/SAUR.git
cd SAUR/headroom-git
less PKGBUILD
makepkg -si
```

Packages with AUR dependencies require those dependencies to be built first. An AUR helper can resolve them while building a local recipe:

```bash
cd SAUR/headroom-git
paru -Bi .
```

Never run `makepkg` as root.

## Update a VCS package

A `-git` package resolves the current upstream revision while building. Refresh it with:

```bash
cd headroom-git
git pull --ff-only
makepkg -Csi
```

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
