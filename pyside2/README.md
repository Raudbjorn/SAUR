# pyside2

[PySide2](https://wiki.qt.io/Qt_for_Python), the Qt 5 bindings for Python, as
the split packages `shiboken2`, `python-shiboken2`, `pyside2` and
`pyside2-tools`. Based on the AUR `pyside2` recipe (envolution) at
5.15.16+4-1. Upstream is 5.15.19, the latest open-source Qt for Python 5.15
release.

## Changes from the AUR recipe

- **5.15.19 with Debian 5.15.18-1 patches.** Debian removed pyside2 from sid
  after 5.15.18-1, so the AUR source URL for `pyside2_5.15.16-4.debian.tar.xz`
  now returns 404. The patch set comes from snapshot.debian.org, which never
  changes a published file. Every patch applies to 5.15.19 except
  `blacklist-failing-tests.patch`, which edits only the test blacklist and is
  skipped because tests are not built.
- **Python 3.14.** None of the Debian patches covers it. Three local fixes:
  - `python-3.14.patch`: lets `setup.py` accept 3.14, and accepts the
    `quote_annotation_strings` keyword that 3.14's `inspect` now passes to
    PySide's replacement `formatannotation()`. Without it, stub generation
    fails with a `TypeError`.
  - `python-3.14-metaclass-tp_new.patch`: from msys2
    ([MINGW-packages #28068](https://github.com/msys2/MINGW-packages/pull/28068)).
    Python 3.14 makes `PyType_FromSpec*` reject metaclasses with a custom
    `tp_new` ([cpython gh-123909](https://github.com/python/cpython/issues/123909)),
    and `import PySide2.QtCore` segfaults in `introduceWrapperType()`. The
    patch installs the stock `tp_new` while each wrapper type is created.
    msys2's 3.14 version-gate patch is identical to the first hunk of
    `python-3.14.patch`.
- **libclang 21 for header parsing.** With libclang 24 (the version tested),
  shiboken2 (end-of-life upstream) resolves unqualified nested types to the
  wrong class. LLVM 22 removed `ElaboratedType`, which points to 22 as the
  first affected release; 22 and 23 were not tested. One example:
  `QNetworkProxy::Capabilities` becomes
  `QNetworkConfigurationManager::Capabilities`, and dozens of generated
  wrappers then fail to compile. The recipe sets `LLVM_INSTALL_DIR` to
  `/usr/lib/llvm21` (`extra/clang21` and `extra/llvm21`). GCC still compiles
  everything; libclang only parses headers. The AUR `shiboken2` package
  declared no clang dependency at all; it now depends on `clang21`, which
  provides `/usr/lib/libclang.so.21.1`.
- **Ninja.** The build uses Ninja instead of make, with `-jN` taken from
  `MAKEFLAGS`. Links run in a separate pool of `jobs / 6`, so 24 concurrent
  LTO links cannot exhaust memory. The `.build-complete` marker, which skipped
  `build()` entirely on reruns, is gone: Ninja rebuilds incrementally anyway.
- **`cmake-pyi-deps-and-install.patch`.** Ninja exposed an ordering bug.
  Nothing makes the `*_pyi` stub targets depend on the shiboken2 Python
  module, so `generate_pyi.py` could run before
  `shiboken2.cpython-*.so` existed. Python then imported the generator's
  `shiboken2/` output directory as an empty namespace package and failed with
  `NameError: _init_pyside_extension`. The patch adds the missing edge.
  It also fixes the stub install: upstream used a configure-time `file(GLOB)`
  over the wrong directory, so the 43 generated `.pyi` stubs were never
  packaged. They now are.
- **Smaller fixes.** `LLVM_INSTALL_DIR` was `/usr/bin` instead of a prefix,
  and the numpy include path now comes from `numpy.get_include()` instead of
  being hard-coded.

## Host tuning

The recipe adds no CPU flags of its own: `-march`, `-O3`, LTO and mold come
from `makepkg.conf`. On a Ryzen 9 7900X3D with `-march=znver4`, the packaged
`QtCore` module contains 185 AVX-512 (`zmm`) and 385 AVX2 (`ymm`)
instructions from GCC 16.2. At 24 jobs, a cold `makepkg --cleanbuild`
compiled everything and reached stub generation in about 4 minutes; that run
then hit the `*_pyi` ordering bug described above. The complete rebuild of the
same source path, with ccache warm, took 104 s.

## Dependencies outside the official repositories

Arch dropped most Qt 5 modules from `extra`. These were used for the build
recorded here:

- `qt5-charts`, `qt5-webengine`, `qt5-scxml`, `qt5-remoteobjects`: binary
  packages from the signed `blackarch` repository.
- `qt5-3d`: built from AUR. Under `-march=znver4` the AUR recipe fails in
  `abstractpickingjob.cpp`: `Matrix4x4` resolves to the SSE type while the
  compiler defines `__AVX2__`. Change its `qmake` line to
  `qmake ../kde-qt3d -- -qt3d-simd avx2` on AVX2-capable hosts.
- `libvpx1.15` (AUR): blackarch `qt5-webengine` 5.15.19-7 links
  `libvpx.so.11`, but `extra/libvpx` is now 1.17 (`libvpx.so.12`). Without
  the compat library, the QtWebEngine bindings fail to import, and the build
  fails generating their stubs.

## Build

```bash
paru -S --needed clang21 llvm21 qt5-charts qt5-webengine qt5-scxml qt5-remoteobjects qt5-3d libvpx1.15
makepkg -si
```

## Not verified

- Not built in a clean chroot; `makepkg --cleanbuild` on the host only.
- The upstream test suite is disabled (`BUILD_TESTS=OFF`). Runtime checks
  were a single offscreen smoke test:
  - all 43 modules imported;
  - widgets were created, a click and a custom `Signal(int, str)` both fired
    through the event loop;
  - `QNetworkProxy` capability flags round-tripped;
  - `inspect.signature` worked;
  - `shiboken2 --version` ran against libclang 21.

  QML, WebEngine pages, Qt3D scenes and multimedia were not exercised.
- The msys2 `tp_new` swap is safe during single-threaded module import.
  Creating wrapper types from several threads at once was not tested.
- That libclang 21 is sufficient for every module is an inference: all 43
  compiled and imported. When Arch drops `clang21`, the type-resolution
  defect returns.
- `namcap` on the packages reports two kinds of false positive: the
  `shibokensupport.*` modules (embedded and zip-imported at run time), and
  `imp` (referenced only on a Python 2 branch). It also flags `qt5-base` as a
  testing release, which is specific to the build host.
