# protoc-gen-go-git

`protoc-gen-go`, the `protoc` plugin that generates Go code from `.proto`
files, built from the `master` branch of
[protocolbuffers/protobuf-go](https://github.com/protocolbuffers/protobuf-go).
The recipe is derived from the AUR
[`protoc-gen-go`](https://aur.archlinux.org/packages/protoc-gen-go) package,
which builds tagged releases.

## Why a VCS build

Upstream tags releases infrequently; at the time of writing `master` was 12
commits ahead of `v1.36.12`. This package tracks `master` for the newest
generator, paired with a `protobuf-git` `protoc`.

## Naming and conflicts

- `provides=(protoc-gen-go protobuf-go)` and `conflicts=(protoc-gen-go protobuf-go)`:
  all three install `/usr/bin/protoc-gen-go`. Only one can be installed at a time.
- The AUR recipe's `replaces=(protobuf-go)` is dropped. A VCS package should
  not silently replace a stable one during a system upgrade.

## Changes from the AUR recipe

- `git+https` source on `master`, a `pkgver()` from `git describe` restricted
  to `v*` tags, and `git` in `makedepends`.
- `GOTOOLCHAIN=local`: if `go.mod` ever demands a newer Go than the installed
  one, the build fails instead of downloading a toolchain mid-build.
- `go build -p` follows the `-jN` in `MAKEFLAGS`, so throttling set there
  applies to Go as well.
- `check()` uses the same `GOFLAGS`/`CGO_*` environment as `build()`, so the
  tests exercise the configuration that ships.

## Host tuning

The binary is pure Go. Host `CFLAGS` and `LDFLAGS` reach only the external
link step (`-linkmode=external` passes them via `CGO_LDFLAGS`). A
`-fuse-ld=mold` in `LDFLAGS` is therefore honored.

`GOAMD64` is deliberately not set by the recipe. Go reads it from the
environment, so a host-tuned build is:

```bash
GOAMD64=v4 makepkg -si
```

The resulting package is still labelled `x86_64` but needs an AVX-512 CPU.
Labelling it `x86_64_v4` would be accurate, but pacman refuses such packages
unless `Architecture` in `pacman.conf` lists that level. The default
(`GOAMD64=v1`) stays portable. `protoc-gen-go` is a short-lived code
generator, so the runtime gain from `v4` is negligible.

## Not claimed

- Built and tested (`go test ./...`) only on x86_64 with `go 1.27.1`, with and
  without `GOAMD64=v4`. `aarch64` and `i686` are inherited from the AUR recipe
  and were not built.
- No clean-chroot (`pkgctl build`) build was run; dependency completeness rests
  on a host build.
- `namcap PKGBUILD` warns that `i686`/`x86_64` should be `$CARCH`. These are
  the `arch=()` entries themselves, a false positive.
- `namcap` on the package warns that `protobuf` may not be needed. The binary
  does not link it, but the plugin is only useful when `protoc` invokes it.
  The dependency is kept, as in the AUR recipe.
- `protoc-gen-go --version` reports `v1.36.12-devel`, a string upstream
  hardcodes on `master`. The generated-file headers carry the same string.

## Verify

```bash
cd protoc-gen-go-git
makepkg --verifysource
namcap PKGBUILD
makepkg --cleanbuild --clean --force --check
```
