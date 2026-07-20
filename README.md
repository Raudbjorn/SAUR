# SAUR

Sveinbjörn's Arch User Repository: reviewed `PKGBUILD` recipes for software I use that is not yet packaged the way I need.

> [!WARNING]
> This is a personal package-source repository, not an official Arch Linux repository and not the Arch User Repository. Read every `PKGBUILD` before building it.

## Packages

| Package | Description | Status |
| --- | --- | --- |
| [`headroom-git`](headroom-git/) | Full-feature VCS build of Headroom, the LLM context-optimization layer | Buildable with the local `python-installer` bridge and AUR dependencies |
| [`python-installer`](python-installer/) | Temporary 1.0.1 bridge required to build AUR `python-rapidocr` | Remove after configured repositories ship 1.0.1 or newer |

## Repository layout

```text
SAUR/
├── docs/
│   ├── packaging-guide.md   # Local packaging and review workflow
│   └── template.PKGBUILD    # Starting point for a new recipe
├── headroom-git/
│   ├── .SRCINFO             # Generated AUR metadata
│   ├── PKGBUILD             # Package recipe
│   └── README.md            # Package-specific notes
└── python-installer/
    ├── .SRCINFO             # Generated AUR metadata
    ├── PKGBUILD             # Temporary repository-version bridge
    └── README.md            # Removal condition and build notes

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
