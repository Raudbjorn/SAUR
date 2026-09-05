# omp

Source-built Arch package for [`omp`](https://github.com/Raudbjorn/omp), a personal
fork of [oh-my-pi](https://github.com/can1357/oh-my-pi) (itself a fork of
[elikoga/oh-my-pi](https://github.com/elikoga/oh-my-pi)).

The AUR already carries `oh-my-pi-git`, which tracks upstream `can1357/oh-my-pi`
directly from source. This recipe is separate on purpose: it builds a specific
tagged release of the fork above, not upstream `main`.

## Source pin

- `pkgver=14.1.4` from the fork's tag `v14.1.4-acp.1`
  (release asset `omp-14.1.4-acp.1.tar.gz`, digest confirmed against GitHub's
  reported asset checksum).
- The extracted archive's top-level directory is `omp-14.1.4-acp.1/`, not
  `oh-my-pi-14.1.4-acp.1/` — the upstream project's own bundled `PKGBUILD`
  (`Maintainer: Bin Jin`, embedded in the fork's tree) still assumes the old
  name and would fail when the source is extracted or the build starts if
  left unmodified (`sha256sums=('SKIP')` means `--verifysource` itself would
  still pass). This recipe fixes the extracted path and pins a real
  `sha256sums` instead of `SKIP`.

## Naming and conflicts

- `pkgname=omp`, matching the installed binary (`/usr/bin/omp`) and the fork's
  repository name, rather than reusing `oh-my-pi`.
- `conflicts=(oh-my-pi-git)`: both packages install `/usr/bin/omp` from the
  same upstream project. Only one can be installed at a time.

## Known deviation from the packaging guide

`build()` runs `rustup toolchain install` and `bun install`, both of which
touch the network and write outside `$srcdir` (into `~/.rustup`, `~/.cargo`,
`~/.bun`). The packaging guide asks recipes to avoid network activity in
`build()`; this one doesn't, because vendoring the Rust nightly toolchain and
the full `bun` dependency tree is out of scope for this pass. Not fixed here,
left as inherited behavior from the upstream recipe this was adapted from.

## Not claimed

- **Not built.** Only `makepkg --verifysource` and `makepkg --printsrcinfo`
  were run — real source, real checksum, valid metadata. The actual
  `build()` (nightly Rust toolchain install, two `cargo build --release`
  passes, `bun` install and bundle) was not exercised. No `pkg.tar.zst` has
  been produced or installed from this recipe.
- `namcap PKGBUILD` flags two cosmetic warnings inherited from the upstream
  recipe (literal `x86_64` instead of `$CARCH`, use of the internal `msg2`
  helper) — not fixed, not build-affecting.
- The `oh-my-pi-git`/`omp` conflict is asserted from reading both PKGBUILDs
  (both install `/usr/bin/omp`), not from installing both side by side.

## Verify

```bash
cd omp
makepkg --verifysource
namcap PKGBUILD
```

## Build and install

```bash
makepkg -si
```

Requires `rustup` with network access to fetch the `nightly-2026-03-27`
toolchain, and `bun`/`zig` per `makedepends`.
