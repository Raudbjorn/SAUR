# protobuf-c-git

[protobuf-c](https://github.com/protobuf-c/protobuf-c) (C runtime library
`libprotobuf-c` and the `protoc-gen-c` code generator), built from upstream's
`next` development branch. Adapted from the AUR `protobuf-c-git` recipe
(Chocobo1).

## Why this exists

- **`next`, not `master`.** Upstream `master` only moves at release time; it
  has sat on the `v1.5.2` tag since 2025-04. Day-to-day development lands on
  `next`, which at the time of writing is 7 commits ahead, including the
  oneof initialization fix for issue #804. `pkgver()` still derives from the
  `v1.5.2` tag (`1.5.2.r7.g6decaa6`).
- **Builds against current protobuf.** protobuf removed
  `FieldDescriptor::label()`, which `protoc-gen-c` calls in 15 places, so
  unpatched `next` does not compile against `protobuf-git` (libprotoc
  37.0-dev). `protobuf-c-pr797-protobuf34-label.patch` is upstream
  [PR #797](https://github.com/protobuf-c/protobuf-c/pull/797), pinned to
  commit `d39f001`: a `FieldLabel()` helper that rebuilds the label from
  `is_repeated()` / `is_required()`.
- **Missing runtime dependency.** The AUR recipe omits `protobuf`, although
  `protoc-gen-c` links `libprotobuf` and `libprotoc`. This recipe declares
  `protobuf` plus `libprotobuf.so` and `libprotoc.so`. makepkg turns the
  latter into versioned soname dependencies (for example
  `libprotoc.so=36.1.0-64`), so pacman flags the package as broken on a
  protobuf soname bump instead of `protoc-gen-c` failing at run time.
- **`check()` runs the upstream test suite.** It is commented out in the AUR
  recipe.

## Patch handling

`prepare()` applies each `*.patch` with `git apply`, unless
`git apply --reverse --check` shows that the tree already contains it. Once
PR #797 is merged into `next`, the patch is skipped rather than failing the
build. At that point remove it from `source=()`.

## Build

```bash
makepkg -si --check
```

`--check` is only needed when `check()` is disabled in your makepkg.conf
(`BUILDENV=(!check)`). This package conflicts with and replaces the
repository `protobuf-c`. Its `provides` (`protobuf-c=<ver>`,
`libprotobuf-c.so=1-64`) satisfy existing dependents such as `libgadu` and
`libssc`.

## Host tuning

No build flags are set in the recipe: host tuning from `makepkg.conf`
(`-march`, `-O3`, `-flto=auto`, `-fuse-ld=mold`) reaches both the C library and
the C++ generator. The only addition is `-ffat-lto-objects`, inherited from
the AUR recipe, because `options=('staticlibs')` ships `libprotobuf-c.a` and
the archive has to work for consumers that link without LTO.

## Known limitations

- protobuf-c does not support proto3 `optional` fields. `protoc --c_out`
  rejects such files. Support is upstream
  [PR #781](https://github.com/protobuf-c/protobuf-c/pull/781), still open,
  and not included here.
- Recent protobuf marks `GetSourceLocation()` as `nodiscard`, which produces
  about ten `-Wunused-result` warnings in `protoc-gen-c`. They are harmless
  and not patched.
- Inside a clean chroot, `namcap` reports `Unused shared library
  libutf8_range.so` for `protoc-gen-c`. The library is pulled in by
  protobuf's pkg-config link flags, not by this recipe.
