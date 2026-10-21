# detect-it-easy-git

Detect It Easy (`die`, `diec`, `diel`) built from
[horsicq/DIE-engine](https://github.com/horsicq/DIE-engine) `HEAD`, last built
at `4260948` (`4.0.0.r21930`). It is based on the AUR recipe of the same name.

## Why this exists

Upstream `src/CMakeLists.txt` now selects Qt with
`find_package(QT NAMES Qt6 Qt5)`, so it uses Qt6 whenever Qt6 is installed.
The AUR recipe still declares Qt5 dependencies (`qt5-base`, `qt5-script`,
`qt5-svg`, `qt5-tools`). On a host with Qt6 installed, it produces binaries
that link `libQt6*` but declare dependencies on Qt5. This recipe:

- pins Qt6 with `-DQT_DIR=/usr/lib/cmake/Qt6`, so the result no longer
  depends on which Qt is installed;
- declares the packages that provide what the binaries load: `qt6-base`,
  `qt6-declarative` (`Qml`/`QJSEngine` replaces `qt5-script`), `qt6-svg`,
  `libgcc` and `libstdc++`. The transitive entries the old list carried
  (`freetype2`, `icu`, `krb5` and others) are gone.

## Build changes

- The Ninja generator replaces Unix Makefiles.
- makepkg `CFLAGS`/`CXXFLAGS` reach CMake only through the environment.
  `CMAKE_*_FLAGS_RELEASE` add only `-DNDEBUG`. The AUR recipe passed the flags
  a second time through the Release variables.
- The job count comes from `MAKEFLAGS` (`-jN`) and falls back to `nproc`. It
  applies to both `cmake --build` and `git submodule update --jobs`. The AUR
  recipe's hard-coded `-j$(nproc)` ignored `MAKEFLAGS`.
- `package()` ends with `chmod -R g-s "$pkgdir"`. When a checkout's
  directories are setgid, `cp -r` copied the bit into the package and namcap
  flagged every data directory.

Host tuning in `/etc/makepkg.conf` is respected and not duplicated: the build
was confirmed with `-march=znver4 -mtune=znver4 -O3 -flto=auto` in
`CMAKE_CXX_FLAGS`, linked with mold 3.0.0 and GCC 16.2.1.

## Build

```bash
makepkg -si --needed --force
```

The build has about 2900 Ninja steps, because upstream compiles the shared
engine sources once for each of `die`, `diec` and `diel`.

## Known upstream issues

- All 22 `.ts` catalogs are empty stubs, so the `.qm` files contain no
  translated strings. `lrelease` reports "Generated 0 translation(s)".
- `diec <symlink>` prints nothing and exits 0. Scan `readlink -f <path>`.
- `diec /usr/bin/ls` reports `TinyCC (0.9.27)` next to GCC. This is probably
  a signature false positive.
- `db_extra/` is installed, as in the AUR recipe, but no application code
  references it. Upstream's own `PKGBUILD` merges it into `db/`.

## namcap

`E: ELF files outside of a valid path ('opt/')` comes from the `/opt` layout
inherited from the AUR recipe. `W: Dependency included, but may not be needed
('qt6-svg')` is expected: no binary links `libQt6Svg`, but Qt loads the SVG
image and icon-engine plugins at run time for the SVG icons.
