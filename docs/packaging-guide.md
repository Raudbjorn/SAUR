# Arch Packaging Guide

This handbook records the workflow used for package recipes in SAUR. It is intentionally concise. Arch's manuals and wiki remain authoritative and should be consulted whenever this guide and current tooling disagree.

## 1. Review before building

A `PKGBUILD` is executable Bash. Read it as code before running `makepkg`:

- confirm every source URL and repository owner;
- reject install commands that write outside `$pkgdir`;
- reject `sudo`, privilege escalation, and opaque downloaded scripts;
- confirm checksums, signatures, and license metadata;
- inspect `prepare()`, `build()`, `check()`, and `package()` for network access or host modification;
- check that secrets, user configuration, and home-directory paths are absent.

Build as an unprivileged user. With `-s`, `makepkg` uses the configured privilege helper only to ask pacman to install declared dependencies.

## 2. Package structure

Each package directory should contain only files needed to reproduce the package:

```text
package-name/
├── PKGBUILD
├── .SRCINFO
├── README.md       # when package-specific caveats need explanation
├── *.install       # only when pacman hooks cannot perform the task
└── patches/        # small, auditable downstream patches
```

Do not commit `src/`, `pkg/`, built archives, local upstream clones, or credentials.

### Lifecycle functions

- `prepare()` applies patches and prepares locked dependency sources. It must be repeatable.
- `pkgver()` derives a deterministic version for VCS packages.
- `build()` compiles without writing to the live filesystem.
- `check()` runs focused upstream tests when they are reliable and feasible.
- `package()` installs only beneath `$pkgdir`.

Use quoted paths and fail-fast commands. Avoid shell cleverness whose only achievement is making audits theatrical.

## 3. VCS packages

A package tracking Git uses the `-git` suffix and a `git+https` source:

```bash
pkgname=example-git
source=('example::git+https://github.com/owner/example.git')
sha256sums=('SKIP')

pkgver() {
  cd example
  git describe --long --tags --abbrev=7 2>/dev/null \
    | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
}
```

When upstream has no tags, combine the declared project version, revision count, and abbreviated commit. `pkgver()` must never depend on wall-clock time.

A VCS package normally declares the stable identity in `provides` and conflicts with that stable package. Verify names against official repositories and AUR first: unrelated projects sometimes share a command or an unfortunately generic name.

## 4. Dependencies

Classify direct dependencies by when they are required:

- `depends`: required at runtime and therefore also present while building;
- `makedepends`: required only to produce the package;
- `checkdepends`: required only by `check()`;
- `optdepends`: enables a genuinely optional runtime capability.

Do not list packages from `base-devel` as build dependencies. Do not rely on transitive dependencies. Translate language-ecosystem names to Arch package names and verify version constraints against the current rolling repositories.

A plain `makepkg -s` installs missing dependencies from configured pacman repositories; it does not build AUR packages. Build AUR dependencies separately or use an AUR helper such as `paru -Bi .`.

## 5. Build isolation

Use source-local caches when a build system otherwise writes into `$HOME`:

```bash
export CARGO_HOME="$srcdir/cargo-home"
export npm_config_cache="$srcdir/npm-cache"
```

Locked manifests make a dependency graph repeatable, but they do not make a package reproducible by magic. Avoid network activity in `build()` and `package()`, honor Arch compiler flags, strip paths and timestamps when upstream permits it, and test in a clean chroot:

```bash
pkgctl build
```

For local iteration:

```bash
makepkg --cleanbuild --clean --force
```

## 6. `.SRCINFO`

`.SRCINFO` is generated metadata consumed by AUR tooling. Never edit it manually:

```bash
makepkg --printsrcinfo > .SRCINFO
```

Verify that the committed file is current:

```bash
(
  tmp=$(mktemp) &&
  trap 'rm -f "$tmp"' EXIT &&
  makepkg --printsrcinfo > "$tmp" &&
  cmp -s .SRCINFO "$tmp"
)
```

Regenerate after changing versions, architectures, dependencies, sources, provides, conflicts, or package descriptions.

## 7. Validation

Run the narrow checks first and the expensive checks last:

```bash
bash -n PKGBUILD
makepkg --verifysource
makepkg --printsrcinfo
namcap PKGBUILD
makepkg --cleanbuild --clean --force
namcap ./*.pkg.tar.zst
```

Then inspect the package archive:

```bash
tar -tf ./*.pkg.tar.zst
```

Confirm expected executables, libraries, licenses, configuration files, ownership, and paths. Install in a disposable environment when practical and exercise the primary command.

A successful local build does not prove dependency completeness; a clean-chroot build is the final packaging gate.

## 8. Maintenance checklist

1. Fetch the latest upstream revision or release.
2. Review upstream build, dependency, license, and command changes.
3. Update the recipe and reset `pkgrel` when the upstream version changes.
4. Regenerate `.SRCINFO`.
5. Build from a clean tree.
6. Run namcap and inspect the archive.
7. Commit the recipe and generated metadata together.

## Authoritative references

- [PKGBUILD(5)](https://man.archlinux.org/man/PKGBUILD.5)
- [makepkg(8)](https://man.archlinux.org/man/makepkg.8)
- [Arch package guidelines](https://wiki.archlinux.org/title/Arch_package_guidelines)
- [Creating packages](https://wiki.archlinux.org/title/Creating_packages)
- [VCS package guidelines](https://wiki.archlinux.org/title/VCS_package_guidelines)
- [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [Building in a clean chroot](https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot)
- [Reproducible builds](https://wiki.archlinux.org/title/Reproducible_builds)
- [namcap](https://wiki.archlinux.org/title/Namcap)
