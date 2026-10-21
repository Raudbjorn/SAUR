# `magika-git`

Arch VCS package for the Rust CLI of [Magika](https://github.com/google/magika), Google's AI-powered file content type detector.

This recipe tracks upstream `main`. The newest CLI release, `cli/v1.1.0`, still runs inference through ONNX Runtime via the `ort` crate. Upstream has since replaced that with an embedded [tract](https://github.com/sonos/tract) runtime and added `magika-rules`, a YARA-subset format-rule engine. The resulting binary depends only on `glibc` and `libgcc`.

The recipe started from the AUR [`magika`](https://aur.archlinux.org/packages/magika) recipe by repsac.

## Name collision

Two packages already install `/usr/bin/magika`:

- AUR `magika` is the stable release build of this CLI;
- AUR `python-magika` installs the Python wheel, which bundles the same CLI, and provides `magika-cli`.

Consequently this recipe:

```bash
provides=("magika=$pkgver" 'magika-cli')
conflicts=('magika' 'magika-cli')
```

`headroom-git` depends on `python-magika`, so it cannot be installed alongside this package.

## Dependency lock

The build uses upstream's `Cargo.lock` (`--locked` / `--frozen`) and a source-local Cargo home. Do not refresh the lock: on 2026-10-21, `cargo update` moved tract from 0.23.4 to 0.23.9. That release removes `EvalOp::is_stateless`, `tract_gpu::session_handler` and a `tract_linalg::ops` constructor, and `magika-tract-runtime` fails to compile without them.

## CUDA

Upstream's CLI always enables the library's `cuda` feature. `cudarc` loads CUDA at run time, so the binary does not link `libcuda` and runs on the CPU when no NVIDIA driver is present. CUDA inference has not been exercised by this recipe.

## Host tuning

The recipe adds no CPU-specific flags; it inherits `RUSTFLAGS` and Cargo profile settings from `makepkg.conf`. On a Ryzen 9 7900X3D with `target-cpu=znver4`, fat LTO and `codegen-units=1`, a clean build took about 7 minutes. Thin LTO with 16 codegen units built in 5m17s instead of 9m20s. On 4,999 files it produced byte-identical labels and scores, and corpus throughput was within noise (best of five runs: 3.20 s vs 3.19 s).

`check()` deliberately skips `cargo test`. The CLI has no unit tests, and building the test harness repeated the fat-LTO link for 4.5 minutes.

## Validate

```bash
bash -n PKGBUILD
makepkg --verifysource
makepkg --printsrcinfo > .SRCINFO
makepkg --cleanbuild --clean --force --check
namcap PKGBUILD
namcap ./*.pkg.tar.*
```

`check()` runs the built binary over upstream's `tests_data/basic` and `tests_data/previous_missdetections` suites. It fails on any mislabelled file, or if no files were identified.

After installation:

```bash
magika --version
magika -r /usr/share/licenses
```

## Scope

This repository packages Magika but is not affiliated with its upstream maintainers. Report packaging defects here; report application defects to [upstream issues](https://github.com/google/magika/issues).
