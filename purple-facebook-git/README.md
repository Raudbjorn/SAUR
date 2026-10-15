# `purple-facebook-git`

Arch VCS package for [purple-facebook](https://github.com/dequis/purple-facebook),
the Facebook Messenger protocol plugin for libpurple 2 (Pidgin, Finch, BitlBee).

Based on the AUR `purple-facebook-git` recipe (contributors Felix Golatofski and
McLenin), whose last packaged revision was `0.9.6.r8.g1a6711f` (2021). Upstream
restructured its build in March 2026, and the AUR recipe no longer describes it.

## What changed from the AUR recipe

- **No `mercurial`, no download during `build()`.** Upstream used to fetch the
  Pidgin source tree from Mercurial at build time and patch it. Since
  2026-03-04 (`eb8761b` "Apply patches directly", `d25d18c` "Remove the old
  update.sh") the patched sources are vendored in `pidgin/`, so the recipe
  only needs `git`.
- **`prepare()` calls `autoreconf -fi` directly.** Upstream's `autogen.sh` ends
  with `test -z "$NOCONFIGURE" && configure`, so it exits 1 whenever
  `NOCONFIGURE` is set and aborts `prepare()` under `set -e`. `autoreconf`
  (plus `mkdir -p m4`) is all the script does.
- **`./configure --prefix=/usr`.** The old recipe let `autogen.sh` run
  `configure` with no prefix (`/usr/local`). The plugin still landed in the
  right place because `plugindir` comes from `pkg-config purple`, but the
  explicit prefix removes the dependency on that.
- **`--as-needed` re-applied to the libtool `-shared` link**, the same `sed` the
  official Arch `pidgin` recipe used, because libtool moves `LDFLAGS` behind
  the libraries.
- **Direct dependencies declared:** `glib2` and `zlib` were linked but relied on
  transitively. `namcap` now reports no missing or unused dependencies.
- **Metadata:** SPDX `GPL-2.0-or-later` (the sources say "version 2 or later"),
  `arch=('x86_64')` only.

Host tuning (`-march`, LTO, mold) is left to `makepkg.conf`; the recipe hardcodes
no CPU flags.

## Dependencies outside the official repositories

`libpurple` was dropped from the official repositories and now lives in AUR
under pkgbase `pidgin` (2.14.14, the latest Pidgin 2 release). Its build
dependency `libgadu` is AUR-only too. Build order:

```text
libgadu (AUR) -> libpurple (AUR, pkgbase pidgin) -> purple-facebook-git
```

`paru -Bi ./purple-facebook-git` resolves both. Building `pidgin` by hand
requires importing its signing key from `keys/pgp/` first.

**libgadu and `protoc-c`:** libgadu's `prepare()` regenerates protobuf code with
`protoc-c`. If `protobuf-c` was built against an older `libprotoc` than the one
now installed (for example after replacing `protobuf` with `protobuf-git`),
`protoc-c` fails to start and libgadu's `prepare()` aborts. Rebuild `protobuf-c`
against the installed protobuf first.

## Not claimed

- **No Facebook login was tested.** Verification stops at linkage: the installed
  `libfacebook.so` loads with `dlopen(RTLD_NOW)` against libpurple 2.14.14 and
  exports `purple_init_plugin`. It was not loaded in Pidgin or Finch. The commits
  since 2021 are build fixes, not protocol fixes, and Facebook may have changed
  its MQTT/Graph endpoints since then.
- **No test suite.** Upstream has none, so there is no `check()`.
- **No clean-chroot build.** Built with `makepkg --cleanbuild` on the
  packager's host only. libpurple and libgadu are AUR packages, so a
  `pkgctl build` needs them supplied as local packages.
- **Deprecated GLib APIs.** The build emits about 25 deprecation warnings
  (`g_memdup`, `g_type_class_add_private`). They are harmless now, and the build
  will break when GLib removes those functions.

## Verify

```bash
cd purple-facebook-git
bash -n PKGBUILD
namcap PKGBUILD
makepkg --cleanbuild --clean --force
namcap ./*.pkg.tar.zst
```
