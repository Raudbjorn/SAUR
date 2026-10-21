# okteta-qt6-git

Qt6/KF6 build of [Okteta](https://apps.kde.org/okteta/), KDE's hex editor,
from upstream's unreleased port. Based on the AUR
[`okteta-qt6-git`](https://aur.archlinux.org/packages/okteta-qt6-git) recipe by
Błażej Szczygieł.

## Source: port replayed on master

Upstream `master` is still Qt5/KF5. The port lives on
[`work/kossebau/kf6`](https://invent.kde.org/utilities/okteta/-/tree/work/kossebau/kf6),
which is `master` plus one commit ("Dump of port draft to Qt6/KF6", `cbf2b4b`,
2026-09-20). It is not rebased, so it falls behind `master`: 11 commits behind
at the time of writing, all translation syncs.

`prepare()` checks out `origin/master` and cherry-picks the branch's own commits
onto it. The committer name, email and date are copied from each original commit,
so the same upstream state always yields the same commit hash, and `pkgver()`
stays deterministic. If a commit does not apply, `prepare()` aborts the
cherry-pick, prints a warning and builds the port branch unchanged, so it builds
older code instead of failing.

The `g<hash>` in `pkgver` is that local cherry-picked commit. It does not exist
upstream.

The source is KDE's own GitLab (`invent.kde.org`), not the GitHub mirror the AUR
recipe used.

## Changes from the AUR recipe

- **Install prefix:** the AUR recipe has no `-DCMAKE_INSTALL_PREFIX=/usr`, so it
  installs everything under `/usr/local`.
- **Dependencies** follow `CMakeLists.txt` and the linked libraries:
  - `depends` adds `hicolor-icon-theme` and the four compression libraries
    (`bzip2`, `xz`, `zlib`, `zstd`), and drops the duplicate `kxmlgui`.
  - `makedepends` adds `git`, `extra-cmake-modules` and `qt6-tools` (for the
    Designer plugin's `UiPlugin`).
  - `kbookmarks`, `kitemviews`, `kservice` and `shared-mime-info` are required by
    `find_package()` but not linked directly (`--as-needed` drops them), so they
    are `makedepends`.
- **Licenses:** SPDX identifiers from upstream's `LICENSES/`, and the two
  `LicenseRef-KDE-Accepted-*` texts are installed.
- **Package names:** `provides`/`conflicts=(okteta)`.
- **Job count:** Ninja ignores `MAKEFLAGS`, so `build()` passes its `-j` value
  to `cmake --build --parallel`.

## Host tuning

The recipe adds no CPU flags. On the packager's machine, `/etc/makepkg.conf`
already supplies `-march=znver4 -O3`, `-flto=auto`, mold and ccache, and all of
them were confirmed in the generated `build.ninja`. They come from the host
configuration, not from this recipe.

## Known upstream gaps

- **Structures tool:** the port draft does not build it ("missing Structures tool
  for now"), so this package doesn't have it.
- **pkg-config:** `Okteta4Gui.pc` requires `OktetaCore`, but the file installed
  is `Okteta4Core.pc`. This only affects programs building against Okteta via
  pkg-config. Not patched.
- **namcap license naming:** namcap reports `LicenseRef-KDE-Accepted-GPL`/`-LGPL`
  as errors and suggests the scancode names. The KDE names are kept because they
  match upstream's REUSE files and Arch's official KDE packages.

## Not claimed

- **Tests:** none ran (`BUILD_TESTING=OFF`). The only checks were that
  `okteta --version` runs headless (reports 0.26.60), `ldd` shows no missing
  libraries, and namcap reports only the license naming above. The GUI, KParts
  plugin and Designer plugin were not exercised.
- **Clean chroot:** not done (no `pkgctl build`), so dependency completeness
  rests on namcap and reading `CMakeLists.txt`.
- **Fallback path:** tested only against a synthetic two-commit conflict, never
  on the real Okteta history.
- **One configuration:** built and installed once on one machine (GCC 16.2.1,
  Qt 6.12.0, KF 6.31.0).

## Build and install

```bash
cd okteta-qt6-git
makepkg -si
```

Every dependency is in the official repositories.
