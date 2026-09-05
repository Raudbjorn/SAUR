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

## Build isolation and host flags

- `RUSTUP_HOME`/`CARGO_HOME` are scoped under `$srcdir`, and the `PATH`
  export that follows them was updated to match (`${CARGO_HOME}/bin`, not
  the previous hardcoded `${HOME}/.cargo/bin`) — rustup creates its proxy
  shims under `$CARGO_HOME/bin` at `toolchain install` time, so both env
  vars have to move together or the shim lookup breaks.
- `bun install` now runs with `--frozen-lockfile --cache-dir="$srcdir/bun-cache"`
  instead of touching `~/.bun` and allowing a silent lockfile drift.
- `CFLAGS`/`CXXFLAGS` are *not* blanket-unset. `crates/pi-natives/build.rs`
  compiles a vendored C scanner (`tree-sitter-glimmer`) via the `cc` crate,
  which reads `CFLAGS`. Instead, only `-march=`/`-mtune=` tokens are
  stripped from them: the two `cargo build` passes below explicitly target
  `x86-64-v2` ("baseline") and `x86-64-v3` ("modern"); leaving a host tuning
  flag like `-march=znver4` in `CFLAGS` would let it leak into the C
  scanner compiled for the "baseline" variant, quietly defeating the split.
  Arch's hardening flags (`_FORTIFY_SOURCE`, stack-clash-protection, etc.)
  are otherwise preserved. `RUSTFLAGS` is appended to (not replaced),
  keeping the two `-C target-cpu=...` selectors as the effective final say
  for that flag specifically. `CC`/`CXX`/`LDFLAGS` are left alone (no
  script here reads `LDFLAGS`, and cc-rs's default compiler discovery
  matches the host `CC`/`CXX` unset or not).
- Still a real deviation from the packaging guide: `rustup toolchain install`
  and `bun install` both need network access during `build()` (a fresh
  builder has neither the nightly toolchain nor the npm-registry deps
  vendored). Not fixed here — vendoring either is out of scope for this
  pass.

## Native module install layout

`packages/natives/native/index.js` looks for the compiled `.node` addon in
a per-user cache first (XDG data dir or `~/.omp/natives/<version>`), then
falls back to `path.dirname(process.execPath)` — i.e. alongside the running
`omp` binary. The `.node` files are shared objects loaded via `dlopen`, not
executables, so they're installed to `/usr/lib/omp/` at mode `644`, with
relative symlinks left at `/usr/bin/pi_natives.linux-x64-{baseline,modern}.node`
so the executable-directory fallback still resolves.

## Not claimed

- **Not built.** Only `makepkg --verifysource` and `makepkg --printsrcinfo`
  were run — real source, real checksum, valid metadata. The actual
  `build()` (nightly Rust toolchain install, two `cargo build --release`
  passes, `bun` install and bundle) was not exercised. No `pkg.tar.zst` has
  been produced or installed from this recipe. The `RUSTUP_HOME`/`CARGO_HOME`
  relocation, the `cc` crate's read of the stripped `CFLAGS`, and the
  native-module symlink fallback are reasoned from reading the fork's
  source (`build.rs`, `packages/natives/native/index.js`) and confirmed
  bun CLI flags (`bun install --help`), not from a completed build.
- `namcap PKGBUILD` flags two cosmetic warnings inherited from the upstream
  recipe (literal `x86_64` instead of `$CARCH`, use of the internal `msg2`
  helper) — not fixed, not build-affecting.
- The `oh-my-pi-git`/`omp` conflict is asserted from reading both PKGBUILDs
  (both install the same binary path), not from installing both side by side.

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
