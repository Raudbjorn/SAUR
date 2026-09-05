# stably-orca

Source-built Arch package for the [Stably AI Orca](https://github.com/stablyai/orca)
agentic coding IDE.

The upstream Orca project ships Linux artifacts only as `.deb`, AppImage, and `.rpm`.
This recipe builds from the upstream git-tag tarball using system `electron43` and
emits a `--linux dir` tree; it never uses `.deb`/AppImage as `source=()`.

## Source pin

- `pkgver=1.4.187` from upstream tag `v1.4.187`
  (`b5ed2d13e1348b1afe654a891794ca4bb68e4091`).
- `package.json` on the tag reports `"version": "1.4.187"` (the `main` branch is
  ahead and reports `1.4.178-rc.2`); this is why a versioned tarball, not a VCS
  package, is the correct source.
- Vendored `pnpm@10.24.0` tarball, checked in via `sha256sums`, so the build
  does not depend on the system's `pnpm` major.

## Why system electron43 (not bundled Chromium)

`electron-builder --linux dir` with `electronDist=/usr/lib/electron43` lets
the distro ship Chromium security updates. The unpacked Electron binaries
land in `dist/linux-unpacked/`; this recipe only copies the `resources/`
subtree into `/usr/lib/stably-orca/`, leaving Chromium at the system path.

## Why `.nvmrc`

`extra/nodejs` is currently on the v26 line, but upstream `package.json`
declares `"engines": { "node": "24" }`. `makedepends` pins
`extra/nodejs-lts-krypton` (Node 24 LTS), which conflicts with `nodejs` so
pacman swaps it in for the build. `prepare()` still checks the running
`node`'s major version against `.nvmrc` defensively, in case that mapping
ever drifts.

`extra/nodejs` moved past the v24 line to v26 and won't come back to it;
`nodejs-lts-krypton` is the durable fix for as long as upstream pins
`engines.node` to `"24"`. If upstream bumps that engine major, switch
`makedepends` to whichever `nodejs`/`nodejs-lts-*` package provides it.

## Verify

```bash
cd stably-orca
makepkg --verifysource
makepkg -fs
namcap PKGBUILD
namcap stably-orca-*.pkg.tar.*
```

## Install

```bash
sudo pacman -U stably-orca-1.4.187-1-x86_64.pkg.tar.zst
```

Smoke:

```bash
orca-ide --help
```

## Launch

- GUI: `stably-orca` (system `electron43` runs `/usr/lib/stably-orca/app.asar`).
- CLI: `orca-ide` (system `electron43` runs the packaged CLI script with
  `ELECTRON_RUN_AS_NODE=1`).

The recipe never installs `/usr/bin/orca`; that name belongs to
`extra/orca` (the GNOME screen reader).

## Conflicts

- `stably-orca-bin` (AUR, AppImage-extract)
- `stably-orca-git` (AUR, AppImage-extract with a stale `pkgver()`)
- `orca-ide`, `orca-ide-bin` (AUR, rpm + system electron)

## Known build-time warnings (cosmetic)

`makepkg` flags `$srcdir` references inside
`/usr/lib/stably-orca/node_modules/node-pty/build/`. Those paths are
`node-gyp` build metadata, never read at runtime, and are an upstream
concern; do not chase them in this recipe.
