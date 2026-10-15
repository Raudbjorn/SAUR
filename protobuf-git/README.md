# protobuf-git

VCS build of [Protocol Buffers](https://github.com/protocolbuffers/protobuf)
`main`, split into `protobuf-git` (C++ libraries, `protoc`, upb plugins) and
`python-protobuf-git` (Python runtime with the native upb backend).

Adapted from the AUR `protobuf-git` recipe (Chocobo1). AUR still carries that
recipe; this one differs in ways that change what gets installed, listed below.

## Differences from the AUR recipe

### The Python extension is actually built

`python/dist/setup.py` collects its C sources with globs (`python/**/*.c`,
`upb/**/*.c`, `utf8_range/*.c`, `google/protobuf/*.c`) that only match the
layout of upstream's Bazel-generated sdist (`//python/dist:source_tarball`).
Run from a raw git checkout, as the AUR recipe does, every glob matches nothing.
The result is a 4 KB `google._upb._message` with no `PyInit__message`, and
`google.protobuf` silently falls back to the pure-Python backend
(`api_implementation.Type() == 'python'`).

`build()` now stages that sdist layout in `$srcdir/python-dist`:

- `python/*.c`, `python/free_threading/*`: the `//python:message_srcs` set;
- `upb/**`: headers from `//upb:source_files`, plus `.c`/`.hpp`/`.inc` from the
  per-directory `source_files` groups that `//python/dist` consumes;
- `utf8_range/`: `//third_party/utf8_range:utf8_range_srcs`;
- `google/protobuf/descriptor.upb*.{c,h}`, `json_enumvalue_options.upb*.{c,h}`:
  generated with the freshly built `protoc-gen-upb`, `protoc-gen-upb_minitable`
  and `protoc-gen-upbdefs` (Bazel `:generated_bootstrap`).

The installed extension is about 600 KB, and `api_implementation.Type()` reports `upb`.

### Generated Python files that setup.py never creates

`setup.py` packages whatever `.py` files exist and never runs `protoc`. A git
checkout has no generated descriptors, so `build()` creates them with the
freshly built `protoc`:

- `internal/python_edition_defaults.py`: `protoc --edition_defaults_out`,
  octal-escaped into the template (Bazel `compile_edition_defaults` +
  `embed_edition_defaults`);
- 14 `*_pb2.py`/`*_pb2.pyi` modules: the well-known types, `descriptor`,
  `compiler/plugin`, `json_options`, `json_enumvalue_options`
  (Bazel `//python:copied_wkt_proto_files`).

Without these, `from google.protobuf import descriptor_pb2` raises `ImportError`.

Test modules are excluded with the same patterns as Bazel `:python_src_files`.

### Build and packaging changes

- **Ninja** generator (`cmake --build` / `cmake --install`).
- **No `-ffat-lto-objects`.** The only static archive, `libupb.a`, is removed by
  `!staticlibs`, so fat objects only doubled the codegen work.
- **`-fmacro-prefix-map`** for the C++ tree and the Python staging tree. abseil
  `LOG`/`CHECK` embed `__FILE__`, so the built libraries and `protoc` contained
  the build directory and makepkg warned "Package contains reference to
  `$srcdir`". Diagnostics now print `src/google/protobuf/...`.
- **Parallel `build_ext`** (`setup.cfg`, `parallel = $(nproc)`) for the ~90 C
  sources of the extension.
- **`pkgver()`** accepts only plain `vN.M` tags. Upstream now also tags
  `vNN-dev` and `vNN.M-rcK`; the AUR filter (drop `rc`) let `v37-dev` through,
  and makepkg rejects the hyphen.
- Licenses are installed under `/usr/share/licenses/$pkgname`.
- `arch=('x86_64')`: i686 was never built or tested here.
- Host tuning (`-march`, `-O3`, LTO, linker, ccache, `-j`) is left to
  `makepkg.conf`; the recipe adds none.

## Soname coupling: read before upgrading

`libprotobuf.so` carries the in-tree version (`38.0.0` at the time of writing),
not the package version derived from the last release tag (`36.2.r920...`).
Every time upstream `main` crosses a major version, the soname changes. Packages
linked against the old soname (grpc, opencv, arrow, onnx, pytorch, qt6-grpc,
mosh, ...) then fail to start, and pacman cannot detect it: they depend on the
unversioned `protobuf`, which this package `provides`.

Before installing a build with a new soname, either rebuild those consumers or
keep the old runtime libraries installed (for example a small
`protobufNN.M-compat` package that ships only `lib*.so.NN.M.0`). Then check:

```bash
pacman -Qi protobuf-git | sed -n 's/^Required By *: //p' | tr ' ' '\n' \
  | xargs -r pacman -Qlq | xargs -r ldd 2>/dev/null | grep 'libproto.*not found'
```

The same applies to abseil: `protoc` links abseil's versioned sonames
(`libabsl_*.so.2601.0.0`), so rebuild this package after any `abseil-cpp`
change.

## Not claimed

- **Not built in a clean chroot.** All builds used `makepkg` on one host
  (gcc 16.2, abseil-cpp 20260107.1, Python 3.14). Dependency completeness is
  asserted from the recipe and `namcap`, not from `pkgctl build`.
- **No C++ tests.** `protobuf_BUILD_TESTS=OFF`, `check()` is empty, and builds
  run with `--nocheck`. The C++ side is verified only by `protoc` generating
  C++/Python code and by existing consumers loading without missing libraries.
- **Python tests ran against an ad-hoc tree.** Upstream's
  `google/protobuf/internal` suite passed (1867 passed, 0 failed) against the
  installed upb extension, with test protos generated by the new `protoc`
  outside the package. It excluded `proto_api_test.py` and
  `recursive_message_pybind11_test.py`, which need Bazel-built pybind11
  modules. This is not wired into `check()`.
- **The staged source set is mirrored from Bazel by hand.** If upstream adds a
  upb directory to `//python/dist`, the extension will fail to link or miss
  symbols until the staging list is updated.
- Remaining `namcap` findings are inherited from upstream's wheel contents
  (`internal/numpy/numpy_test.py` and `internal/message_benchmark.py` import
  `absl`, `numpy`, `google_benchmark`) or are cosmetic (`libm` unused by
  `libprotoc`; `python-protobuf-git` → `protobuf-git` kept for version lockstep).

## Build and install

```bash
cd protobuf-git
makepkg --cleanbuild --clean --force --nocheck
```

Then install both split packages together with `pacman -U`, after reading
"Soname coupling" above.
