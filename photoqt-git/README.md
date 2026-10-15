# photoqt-git

VCS build of [PhotoQt](https://photoqt.org/) from upstream
[`lspies/photoqt`](https://gitlab.com/lspies/photoqt) `master`. It's adapted
from the AUR `photoqt` recipe (maintainer Lukas Spies, who is also upstream).

## Why this exists

AUR `photoqt` builds the latest release tarball. Upstream `master` has moved
past it (`5.4.1.r14` at the time of writing). The newer commits add an OpenSlide
image plugin, libvips/DevIL write support and thumbnail fixes. This recipe
tracks `master` under the `-git` name rather than editing the stable package.
`photoqt-git` and AUR `photoqt-git` don't collide: no AUR package of that name
existed when this recipe was added.

## Differences from AUR `photoqt`

- **Source:** `git+https` on `master` with `pkgver()`, instead of a pinned tarball.
- **Build system:** builds with Ninja in a separate `build/` directory instead
  of an in-tree Make build, and installs with `cmake --install`. Ninja ignores
  `MAKEFLAGS`, so `build()` copies its `-jN` value to `CMAKE_BUILD_PARALLEL_LEVEL`.
- **resvg re-enabled.** AUR `photoqt` 5.4-2 turned resvg off because of a broken
  header in the resvg package. resvg 0.48.1 ships `/usr/include/resvg/resvg.h`
  correctly, and the plugin compiles and links (`libresvg.so.0.48`).
- **OpenSlide enabled and declared.** The plugin is new upstream and defaults
  to `ON`. With OpenSlide installed, an unmodified recipe would pick it up
  silently and link `libopenslide.so.1` without declaring the dependency.
- **Direct dependencies completed.** The package now declares the libraries the
  binary links directly, as namcap reports them: `qt6-base`, `openssl`, `wayland`,
  `glibc`, `libgcc` and `libstdc++`.
- **`provides=('photoqt-debug')` dropped.** The AUR recipe advertises a
  debug package it doesn't ship. The `-git` package provides `photoqt=$pkgver`
  and conflicts with `photoqt`, `photoqt-bin` and `photoqt-bin-debug`.
- **Metadata:** SPDX `GPL-2.0-or-later` (the source headers say "version 2 ... or
  any later version") and an `https` URL.

## Host tuning

No compiler-flag changes. `/etc/makepkg.conf` on the packager's host already
supplies `-march=znver4 -O3`, `-flto=auto` and `-fuse-ld=mold`, and all of them
appear in the generated `build.ninja`. CMake's `Release` type adds `-O3 -DNDEBUG`.

## namcap

`namcap PKGBUILD` is clean. On the built package:

- *"Dependency included, but may not be needed"* for `kimageformats`,
  `qt6-imageformats`, `qt6-location`, `qt6-positioning`, `qt6-quick3d`,
  `openmp` and `python-pychromecast`. These are false positives: they're Qt
  image-format/QML plugins and a Python module loaded at runtime, not ELF
  `NEEDED` entries. Keep them.
- *"Referenced QML module ... uninstalled"* for `PhotoQt`, `ExtensionSettings`,
  `sys`, `time` and `pychromecast`. The first two are compiled into the
  binary; the others are Python imports in the Chromecast helper.

## Not claimed

- **No clean-chroot build.** The package was built with
  `makepkg --cleanbuild --clean --force` on the packager's host. `pkgctl build`
  wasn't run, so the dependency list hasn't been proven complete in a minimal
  chroot.
- **No `check()`.** Upstream has a `WITH_TESTING` option. It wasn't explored.
- **Limited runtime testing.** It was tested with an equivalent local build
  (same flags and commit, stable package name): PhotoQt launched offscreen
  with a temporary `HOME` and loaded a PNG. The GUI wasn't used on a real
  display, and no slide, SVG, video or Chromecast paths were exercised.
- **Upstream noise on `master`.** A fresh profile logs "Unable to open settings
  database" once on the first launch. Every launch logs two "current version
  number needs to be added to the migrate() functions" warnings, because
  `master` still reports version 5.4.1. These come from the unreleased branch,
  not from this recipe.
- **Upstream CMake warnings.** `FindOpenSlide.cmake` passes `OPENSLIDE` to
  `find_package_handle_standard_args` instead of `OpenSlide`, and policy
  `QTP0004` is set to `OLD`. Both only warn; detection works.
- **Moving target.** `master` can break at any commit. The verified revision is
  `7d35e6f`.

## Build and install

```bash
cd photoqt-git
makepkg -si
```

For the extensions, build [`photoqt-extensions-git`](../photoqt-extensions-git/) afterwards.
