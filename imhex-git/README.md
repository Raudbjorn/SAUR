# imhex-git

VCS build of [ImHex](https://github.com/WerWolv/ImHex), the hex editor for
reverse engineers, from upstream `master`, with
[ImHex-Patterns](https://github.com/WerWolv/ImHex-Patterns) `master` installed
alongside. Derived from Arch's `imhex` 1.38.1-2 recipe (KokaKiwi, George
Rawlinson), which builds the release tarball.

## Why not the Arch package

Arch's `imhex` builds 1.38.1, released 2025-12-21. Upstream `master` is 681
commits further on (1.39.0.WIP at `34483cb`, 2026-10-08) and has changed its
dependency set: .NET 10 instead of 9, TF-PSA-Crypto support for mbedtls 4,
md4c, Boost.Regex. The release recipe does not build it unchanged.

## Version

`pkgver()` takes the newest `v*` tag and counts commits since it:
`1.38.1.r681.g34483cb905`. `master` diverged from the `v1.38.1` release
branch, so `git describe` would pick an older tag. The scheme sorts below the
coming 1.39.0, so a stable `imhex` 1.39.0 replaces this cleanly.
`provides=(imhex=<last release>)` and `conflicts=(imhex)`.

## Deviations from Arch's recipe

| Change | Reason |
| --- | --- |
| Bundled CLI11 (`USE_SYSTEM_CLI11=OFF`) | With Arch's `cli11` 2.7.2 the build succeeds, but `builtin.hexplug` is left with `CLI::Config::from_file` undefined and fails to `dlopen`. Every CLI subcommand lives in that plugin, so `imhex --version` aborts on an empty `std::optional` (exit 6). PatternLanguage's `cli/source/main.cpp` includes only `<CLI/App.hpp>`, which no longer pulls in the inline definition. |
| Bundled LLVM demangler (`USE_SYSTEM_LLVM=OFF`) | Avoids tying the package to an LLVM soname. On hosts with `llvm-minimal-git` that soname changes on every update. |
| Bundled GLFW and Capstone | What upstream's Arch CI uses. Upstream warns that system GLFW lacks its patches, and the pinned Capstone is newer than Arch's 5.0.x. GLFW `dlopen`s X11/Wayland/libGL, so those stay in `depends` even though namcap calls them unneeded. |
| System `md4c`; `yara`, `fmt` and `nlohmann-json` stay system | Matches upstream's Arch CI |
| `IMHEX_ENABLE_UPDATER=OFF` | Replaces deleting `imhex-updater` after install |
| LTO enabled (Arch's recipe sets `!lto`) | Built and smoke-tested with makepkg's `-flto=auto`. `CMAKE_AR`/`CMAKE_RANLIB` are set to `gcc-ar`/`gcc-ranlib` for the static internal libraries. |
| Ninja; `-jN` taken from `MAKEFLAGS` | Ninja ignores `MAKEFLAGS` |
| `-ffile-prefix-map` and MSBuild `PathMap` | Removes the makepkg "reference to `$srcdir`" warning from the native code and from `AssemblyLoader.dll` |
| Patterns `tests/` not installed | Fixture data for the patterns repo's CI, not read by ImHex at runtime. Removing it takes the package from 53 MB to 28 MB and clears two namcap errors about ELF files outside valid paths. |
| `package()` runs `chmod go-w` and clears setgid on dirs | A `BUILDDIR` with a default ACL or setgid directories otherwise leaks group-writable files and setgid dirs into the package |
| .NET CLI telemetry off during `build()` | `dotnet build` builds the `AssemblyLoader` |

## Submodules are sources

ImHex pins 23 submodules, recursively; libwolv and fmt are each nested
several times. All 18 distinct repositories are listed in `source=()`.
`prepare()` rewrites each submodule URL to the matching `$srcdir/<name>`
clone and checks out the commit upstream pins, one level at a time. `prepare()`
therefore makes no network requests, and rebuilds reuse the `SRCDEST`
mirrors: download, extract and prepare took 17 s cached. The previous
`git submodule update --init --recursive` took 26 s every build.

Submodules stay at upstream's pins. When this was written the WerWolv-owned
ones matched their own tips, except libwolv, which was two CI-only commits
behind.

ImHex-Patterns has a gitlink at `yara/official_rules/utils/yara-forensics` with
no `.gitmodules` entry. It cannot be fetched, so that directory ships empty.

## Host tuning

No architecture flags in the recipe: it uses makepkg's `CFLAGS`/`LDFLAGS`. On
the packager's Ryzen 9 7900X3D (`-march=znver4 -O3`, mold, 24 jobs):

| Build | Wall time |
| --- | --- |
| Cold, empty compiler cache | 5 m 55 s |
| Warm sccache | 1 m 21 s – 3 m 08 s |

If the environment sets `CMAKE_CXX_COMPILER_LAUNCHER` (for example sccache),
`build()` removes makepkg's ccache shim from `PATH`, so each compile goes
through one cache instead of sccache wrapping ccache.

## Not claimed

- **No clean-chroot build.** Built with `makepkg -fC` on the packager's host
  only, so dependency completeness is checked against namcap and `readelf`
  `NEEDED`, not a `pkgctl build`.
- **Smoke-tested under the earlier `imhex` package name.** The binaries came
  from this recipe's build flags, with `prepare()` still fetching submodules
  over the network. Tested: `imhex --version-short` printed `1.39.0.WIP`,
  `imhex --hash sha256` matched `sha256sum`, and the GUI ran 10 s with all 11
  plugins loaded and no logged errors. The `imhex-git` package itself was built
  and its file list compared identical, but it was not installed.
- **.NET scripting not exercised.** CMake found .NET 10.0.13 and built
  `AssemblyLoader.dll`; no C# script was run.
- **No runtime benchmark.** Nobody has measured whether LTO or `-O3` make ImHex
  itself faster; only build times were measured, each from a single run.
- **ImHex prints nothing when stdout is not a terminal.** Upstream's logger
  behaviour, not this recipe's. Use a TTY (or `script -qc`) for CLI output.
- **namcap false positive:** `Dependency imhex detected and not included` for
  `libimhex.so` appears only while a conflicting `imhex` package is installed,
  because namcap attributes the library to it. This package ships
  `libimhex.so` itself.
- **Any upstream commit can break a `-git` build.**

## Build and install

```bash
cd imhex-git
makepkg -si
```

Needs `dotnet-sdk-10.0` (makedepends) for the .NET script loader.
