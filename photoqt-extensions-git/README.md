# photoqt-extensions-git

VCS build of the official
[PhotoQt extensions](https://gitlab.com/lspies/photoqt-extensions) from
upstream `master`. It's adapted from the AUR `photoqt-extensions` recipe and is
the companion to [`photoqt-git`](../photoqt-git/).

## Why this exists

Upstream `master` is currently the same commit as the `v5.4.1` tag
(`1e39f93`). The code matches the AUR package today, but this recipe follows
`master` as it moves. It also fixes dependency defects in the AUR recipe:

- **`exiv2` removed.** No extension links or includes it. The `NEEDED`
  entries of all four shared objects are Qt6 Core/Gui/Widgets/DBus/Sql/Network
  plus the C/C++ runtime.
- **`qt6-charts` added.** The Histogram extension imports `QtCharts` from QML.
  Without it the AUR package installs fine but that extension fails at
  runtime. namcap flagged it as an error on a build that lacked it.
- **`qt6-declarative`, `qt6-location`, `qt6-positioning` and `photoqt` added.**
  They provide QtQuick, the MapCurrent extension's QML modules and the
  `PhotoQt` QML module the extensions import. `photoqt-git` satisfies the last
  one via `provides`.

The build changes match `photoqt-git`: Ninja with a separate build directory,
`MAKEFLAGS` job count carried over, `cmake --install`, SPDX
`GPL-2.0-or-later`, and the `-git` naming with `provides`/`conflicts`.

## Signature verification

Each extension ships `verification.txt`, which lists hashes of its manifest and
QML files but not of the shared object, plus a `.sig` file over that list.
Rebuilding the `.so` with host flags therefore doesn't affect them. PhotoQt also
skips verification entirely for extensions in the system directory
(`/usr/lib/PhotoQt/extensions`), as seen in `pqc_extensionshandler.cpp`
(`isSystemExtension ? true : verifyExtension(...)`).

## namcap

`namcap PKGBUILD` is clean. On the built package, the only remaining warning
is *"Referenced QML module 'PhotoQt' is an uninstalled dependency"*. The
module is compiled into the `photoqt` binary rather than installed as a
separate QML module, so namcap can't resolve it even with `photoqt` installed.

## Not claimed

- **No clean-chroot build.** `makepkg --cleanbuild --clean --force` on the
  packager's host only; `pkgctl build` wasn't run.
- **Extensions not exercised inside PhotoQt.** The package builds and installs,
  and the dependency fixes come from namcap and `readelf`. No extension was
  opened or used. The signature-skip behaviour comes from reading the source,
  not from watching PhotoQt load them.
- **Moving target.** The verified revision is `1e39f93`.

## Build and install

Install `photoqt-git` (or another package providing `photoqt`) first, then:

```bash
cd photoqt-extensions-git
makepkg -si
```
