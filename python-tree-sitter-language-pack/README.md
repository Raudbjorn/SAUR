# `python-tree-sitter-language-pack`

Arch package for [`tree-sitter-language-pack`](https://github.com/xberg-io/tree-sitter-language-pack) 1.x: 371 tree-sitter grammars exposed to Python, with **every grammar linked into the extension module** so nothing is fetched at run time.

This is a rewrite, not a version bump of the AUR recipe. Upstream 0.x was a setuptools project that cloned its grammars during `prepare()`. Upstream 1.x is a Rust monorepo; the Python distribution lives in `packages/python` and is built by maturin from `crates/ts-pack-core-py` (pyo3, `abi3-py310`). The old recipe's `cython` / `nodejs` / `python-pyproject-patcher` build inputs and its `python-tree-sitter-{c-sharp,embedded-template,yaml}` runtime dependencies no longer exist upstream.

The upstream GitHub organisation also moved from `kreuzberg-dev` to `xberg-io`.

## Why the grammars are linked statically

Upstream's default `TSLP_LINK_MODE=dynamic` emits one shared object per grammar and bakes the absolute build-time `OUT_DIR` into the binary as `LIBS_DIR`. That path cannot survive `$pkgdir`, and when it fails to resolve the library downloads grammars into a per-user cache on first use. Neither behaviour belongs in a distribution package, so this recipe sets:

```bash
TSLP_LINK_MODE=static
TSLP_LANGUAGES=all
```

Both are required. With `TSLP_LANGUAGES` unset, upstream's `build.rs` selects **no** grammars, the build still succeeds, and the result is a grammar-less wheel that downloads at run time. `TSLP_LINK_MODE` alone changes nothing, because it only decides how the selected grammars are linked.

The cost is size: `_native.abi3.so` is roughly 430 MB, about 412 MB installed.

## Offline build

`build.rs` would otherwise download `parser-sources-<version>.tar.zst` itself. That release asset is declared in `source=()` under `noextract=()` and unpacked in `prepare()`, so it is covered by makepkg's integrity check and `build()` needs no network:

- `prepare()` unpacks only `parsers/` from the bundle — `patches/` and `sources/` already exist in the repository tarball and the committed copies are newer;
- `prepare()` runs `cargo fetch --locked` (no `--target`: maturin invokes `cargo metadata`, which resolves the whole workspace across every platform, so a host-only fetch leaves cross-platform-only crates missing);
- `build()` runs with `CARGO_NET_OFFLINE=true` and `--offline --locked`.

## Host tuning

`_tune_build_env()` derives its settings from the local toolchain rather than hard-coding them:

| Setting | Source |
| --- | --- |
| `CARGO_BUILD_JOBS` | the `-j` value in makepkg's `MAKEFLAGS` |
| `-C target-cpu=` | the `-march=` in `CFLAGS`, only if `rustc --print target-cpus` lists it |
| `-C link-arg=-fuse-ld=mold` | applied only when `mold` is installed |
| `CARGO_PROFILE_RELEASE_LTO=thin` | forced, overriding any host-wide `fat` |
| `RUSTUP_TOOLCHAIN=stable` | forced |

Two of these deserve explanation.

Upstream ships a `.cargo/config.toml` pinning `jobs = 4`; it is machine-generated, so the job count is raised through the environment instead of patching the file. Upstream's `rust-toolchain.toml` pins channel 1.95 and requests a `wasm32` target plus extra components, which makes rustup reach for the network mid-build; `RUSTUP_TOOLCHAIN` overrides the file entirely.

`options=('!lto')` is set because the C grammar objects are linked by rustc, not by makepkg's link step, so GCC LTO bitcode would have to cross a toolchain boundary. Cargo already applies thin LTO to the Rust half.

**If your `CFLAGS` carry a specific `-march`, the resulting package is host-specific.** Build with generic `CFLAGS` if you intend to move the artifact between machines.

The grammar compile is single-threaded upstream — `build.rs` loops grammars sequentially, handing `cc::Build` one file each — so the job count only helps dependency crates and rustc. Expect roughly 25 minutes on a cold cache for about 1.9 GB of generated C. Enabling `ccache` in `BUILDENV` is what makes a retry cheap.

## Known upstream defects

Two grammars misbehave in 1.15.0. Both reproduce in upstream's own artifacts and are not caused by this recipe — each was confirmed against a dynamic, upstream-default build of the same tree.

| Grammar | Symptom | Scope |
| --- | --- | --- |
| `typst` | `get_parser('typst').parse(b'#let x = 1')` segfaults in `vec_u32_deserialize` at `scanner.c:213`: the scanner is handed a 16-byte state buffer while its format needs at least 20 | 1.15.0 regression; upstream 1.14.3 parses it correctly |
| `cobol` | `parse(b'x')` never returns | long-standing; upstream 1.14.3 hangs identically |

They are **not** excluded from the build. Filtering them out would make `available_languages()` disagree with upstream and the exclusion list would go stale unnoticed at the next version bump. If you want them gone anyway, replace `TSLP_LANGUAGES=all` with an explicit comma-separated list.

## Licensing

The grammar corpus is overwhelmingly MIT, but one grammar (`RubixDev/ebnf`) is GPL-3.0. Static linking combines it with the rest, which upstream's per-grammar shared-object layout avoided, so `GPL-3.0-only` is declared in `license=()`. Per-grammar terms are installed as `/usr/share/licenses/python-tree-sitter-language-pack/grammar-licenses.json`.

## Build and install

```bash
cd python-tree-sitter-language-pack &&
  makepkg -si
```

`check()` installs the wheel into a throwaway venv and runs upstream's end-to-end suite, excluding `test_download.py` — that suite exercises the runtime downloader, which this package deliberately never uses — along with `test_smoke_typst` and `test_smoke_cobol`, deselected for the defects above (a `--timeout` guards against any other unexpected hang).

Verify afterward:

```bash
python -c 'import tree_sitter_language_pack as p; print(p.language_count()); p.get_parser("python").parse(b"x = 1")'
```

`language_count()` reports 377 rather than 371 because aliases are counted alongside grammars.
