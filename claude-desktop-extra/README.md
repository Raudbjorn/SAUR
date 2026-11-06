# claude-desktop-extra

Claude Desktop (Anthropic's official Linux `.deb`) repackaged with
[patrickjaja/claude-desktop-extra](https://github.com/patrickjaja/claude-desktop-extra)'s
patch set: Computer Use bridges, Quick Entry, multi-profile, themes and so on.

This directory has two build paths:

| Path | What it builds | github-mcp-server |
| --- | --- | --- |
| [`PKGBUILD`](PKGBUILD) | Repacks the upstream **prebuilt** release tarball | Broken (see below) |
| [`native/build-native.sh`](native/build-native.sh) | Builds **from source**: newest apt `.deb`, upstream `HEAD`, host-tuned bridges | Fixed by a local patch |

## `PKGBUILD`: the AUR recipe, unchanged

`PKGBUILD`, `.SRCINFO` and `claude-desktop-extra.install` are byte-identical
to AUR `claude-desktop-extra` at commit `f3cd326` (`4.23118.0-5`). They are
kept here as the reference that `native/build-native.sh` reads its `pkgrel`
from, and as a no-compile fallback.

**Known defect in the prebuilt tarball.** Upstream's repack step runs
`asar pack --unpack "{**/*.node,**/spawn-helper}"`, which leaves
`resources/github-mcp/github-mcp-server` *inside* `app.asar`, where it is not
executable. The app spawns it from `app.asar.unpacked/`, so the GitHub MCP
server fails with `Permission denied`. I checked the `v4.23118.0-5` release
asset: its `app.asar` header lists the 24.9 MB binary with no `unpacked`
flag, and the tarball has no `app.asar.unpacked/.../github-mcp/` entry.

## `native/build-native.sh`: source build

```bash
cd claude-desktop-extra/native
./build-native.sh            # package lands in $CDE_SRC/pkgdest
```

| Variable | Default | Meaning |
| --- | --- | --- |
| `CDE_SRC` | `${XDG_CACHE_HOME:-~/.cache}/claude-desktop-extra-native` | Checkouts, toolchain, logs. Missing repos are cloned on first run |
| `PKG_OUT` | `$CDE_SRC/pkgdest` | Where the finished package is copied |
| `AUR_DIR` | this directory | Recipe whose `pkgrel` is bumped by one when `pkgver` matches the newest apt release, so `paru -Syu` does not "upgrade" back to the AUR build |
| `CARGO_LOCKED=1` | off | Build bridges from their committed `Cargo.lock` only |
| `CRATE_HOLDS_OFF=1` | off | Float the held crates too (see below) |
| `BRIDGE_PARALLEL=0` | parallel | Build the four bridges one at a time |
| `BRIDGES_ONLY=1` | off | Stop after the bridges (benchmarking) |

What the script does:

1. **Sync.** Fast-forwards upstream `gh/` and the four Computer Use bridge
   repositories (`x11`, `wlroots`, `kwin-portal`, `gnome-portal`). If upstream
   rewrote history, it resets only when the local tree exists upstream, and
   keeps a `backup/pre-reset-<date>` branch.
2. **Bridges.** `cargo update` to the newest semver-compatible crates, then
   builds all four under one GNU make jobserver. The total stays at the `-jN`
   taken from `MAKEFLAGS` (or `nproc`). Flags: `-C target-cpu=native`, `mold` if
   installed, fat LTO, `codegen-units=1`, and `sccache` if found. Existing
   `RUSTFLAGS` and `RUSTC_WRAPPER` are respected. If a bridge fails, it is
   rebuilt from its committed lock. `cu-atspi` builds against `main` when
   upstream has moved past the bridges' pin.
3. **Crate holds.** Three crates stay at the committed lock's version because
   their newest releases break a bridge:
   - `winit-common` 0.31.0-beta.4, and the `winit-core` it pins with `=`, made
     the keyboard enums `non_exhaustive`. `iced_exdevtools` 0.19.1 matches them
     exhaustively (E0004). This affects `kwin-portal-bridge`.
   - `lamco-portal` 0.4.7 added `StreamInfo.mapping_id`, and the bridges build
     that struct literally (E0063). This affects `kwin-portal-bridge` and
     `gnome-portal-bridge`.
4. **Package.** Copies `gh/` (without `.git`, `build` or `cache`) to a tmpfs
   stage when `/tmp` has more than 6 GiB free, applies
   `native/local-patches/*.patch` to that copy only, and runs upstream's
   `scripts/build-local.sh`. The checkout itself is never modified, so the
   next sync still fast-forwards. A patch that no longer applies is reported
   but does not stop the build.
5. **Guard.** Refuses to publish a package that contains setgid directories
   or world-writable entries. A setgid-cloning build directory once leaked
   `drwxr-sr-x` into `/usr/lib/claude-desktop`.

Stage timings and non-fatal issues are printed at the end, and also kept in
`$CDE_SRC/.build-timings` and `$CDE_SRC/.build-notes`.

Build requirements: everything `gh/scripts/build-local.sh` needs (`asar`,
`nim`, `python3`, `gpg`, `bsdtar`, `makepkg`), plus `rustup` or a Rust
toolchain with the `x86_64-unknown-linux-musl` target, `make`, `rsync` and
`patch`. If `$CDE_SRC/.toolchain/{rustup,cargo}` exists, it is used and
updated instead of the system Rust. This avoids `rust`/`rust-musl` pkgrel
drift (E0514).

### Local patch

[`0001-asar-unpacked-github-mcp-and-exec-bits.patch`](native/local-patches/0001-asar-unpacked-github-mcp-and-exec-bits.patch)
patches upstream's `scripts/build-patched-tarball.sh`:

- adds `**/github-mcp/github-mcp-server` to the `asar pack --unpack` glob;
- after packing, restores mode `0755` on every file that was user-executable
  in the official `.deb`'s `app.asar.unpacked/`. `asar extract` drops exec
  bits because upstream's header has no `executable` flag.

Result: `github-mcp-server` is installed at `755`, and `--version` prints
`GitHub MCP Server Version: 2.0.2`. This is a workaround until upstream
fixes the issue; it has not been reported upstream yet.

### Pre-install audit

[`native/audit_pkg.py`](native/audit_pkg.py) treats the package and the
upstream `.deb` as untrusted data and never executes anything from them:

```bash
python3 -I native/audit_pkg.py PKG DEB WORKDIR REPO_INSTALL [BRIDGE_BIN...]
# exit 0 = no blocking findings, 1 = blocking, 2 = usage error
```

It checks:

- setuid/setgid files (only `chrome-sandbox` 4755 is allowed);
- world-writable entries, non-root owners, device nodes, and paths outside
  `usr/`;
- the `.INSTALL` script, diffed against `REPO_INSTALL`;
- every file's sha256 **and exec bit** against the `.deb`;
- added or changed `app.asar` entries, and network hosts that appear only in
  the patched JavaScript;
- ELF hardening (PIE, RELRO, NX);
- bridge hashes against the local builds.

Run it on `/tmp` or another filesystem with room: it extracts both archives.

`DEB` must be a `.deb` you have verified yourself. Fetch `Release` and
`Release.gpg` from
`https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/`. Check
them with `gpgv` against
`$CDE_SRC/gh/packaging/claude-desktop-archive-keyring.asc` (dearmored).
Then check that `main/binary-amd64/Packages` matches its SHA256 in `Release`,
and that the `.deb` matches its SHA256 in `Packages`. Upstream's
`build-patched-tarball.sh` follows the same chain.

## Verify

```bash
bash -n PKGBUILD
makepkg --printsrcinfo | cmp - .SRCINFO
makepkg --verifysource
namcap PKGBUILD
bash -n native/build-native.sh && shellcheck -S warning native/build-native.sh
ruff check --line-length 100 native/audit_pkg.py
```

## Not claimed

- **The prebuilt `PKGBUILD` path was not built or installed from this
  directory.** For that path, only `makepkg --verifysource` (checksum passes),
  `.SRCINFO` equality and `namcap PKGBUILD` (clean) were run. The
  github-mcp-server finding comes from reading the release asset's `asar`
  header, not from running the installed binary.
- **The native path is verified on one host only:** Ryzen 9 7900X3D on Arch,
  with KDE Plasma 6 on Wayland. Its packages passed the audit with 0 blocking
  findings, and `pacman -Qkk` reported 0 altered files after install.
  The GUI itself was not launched as part of verification, and nothing tested
  the Computer Use bridges at runtime.
- **First-run bootstrap (cloning into an empty `CDE_SRC`) and the in-place
  fallback (no roomy tmpfs) were not exercised.** In the fallback, local
  patches are deliberately skipped, so that build ships the github-mcp defect.
  The script prints a note when this happens.
- **The intermittent absorbed-patch probe failure is unexplained.** On
  2026-11-06, the upstream P2 idempotency check failed once for
  `fix_quick_entry_wayland_blur_guard.nim`, then passed in 5+ later runs.
  Moving `TMPDIR` into the tmpfs stage is a guess at the cause, not a
  confirmed fix.
- **The crate holds are pinned to specific versions,** and newer bridge
  commits may make them stale or unnecessary. Re-test with
  `CRATE_HOLDS_OFF=1`.
- **Builds are not reproducible.** Upstream `HEAD`, crate versions and the apt
  `.deb` all float, and `CLAUDE_ALLOW_PIGZ=1` (the default here) trades
  byte-reproducibility for speed.
- **Nobody reviewed the logic of the patched JavaScript.** The audit lists
  added network hosts (opt-in providers such as `api.deepseek.com` and
  `openrouter.ai`), but it does not judge what the patches do.
- New state: `CDE_SRC` holds about 4 GB of checkouts, `target/` directories
  and the toolchain. Build and audit runs also need network access: GitHub,
  `crates.io`, and `downloads.claude.ai`.
