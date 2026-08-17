# trailmark-git

[Trailmark](https://github.com/trailofbits/trailmark) parses source code into a
queryable graph of functions, classes, calls, and semantic annotations. This
recipe builds upstream `f7e19d3` (`v0.5.0-2-gf7e19d3`) plus two community fork
patches that are not yet merged upstream.

## What the patches carry

| Patch | Fork | Contents |
| --- | --- | --- |
| `0001-solidity-state-web.patch` | `timefliez1210/feat/solidity-state-web` | Syntactic Solidity state web: `STATE_VARIABLE` nodes, `READS`/`WRITES` edges, inherited-state and storage-pointer attribution, proxy `bare_name` fix, unified query core |
| `0002-java-vuln-poc-example.patch` | `IOJedi/copilot/create-poc-project-java-library-vulnerabilities` | `examples/java-vuln-poc/`, a Java third-party library vulnerability proof of concept driven by Trailmark |

`uv.lock` hunks are stripped from both patches. This package builds against
system dependencies and never reads the lockfile.

### Four surveyed branches are deliberately absent

Six fork branches were surveyed. Four were already merged into `f7e19d3` and
carrying them would be a no-op at best:

| Branch | Evidence |
| --- | --- |
| `hughpyle/public-parse-api` | Five of its six commits match upstream PRs #23, #24, #25 and #26; upstream `parse.py` is a strict superset. The one unique commit is a `ruff format` pass. |
| `alexander-heinrich/fix/file-scoped-namespace-attribution` | `git diff main <tip>` over its files is empty. |
| `Tomer-PL/fix/preproc-recovery` | `git patch-id --stable` equals upstream `4198276` (#35). |
| `Tomer-PL/fix/cross-file-call-linker` | `git patch-id --stable` equals upstream `d46c3e7` (#34). Upstream then improved it in review, dropping `target_id=candidates[0]` so that an ambiguous multi-candidate call keeps its original target instead of inventing one. Re-applying the fork would regress that. |

Each fork's own `origin/main` is 17 to 30 commits stale, which is why their
ahead-counts looked like new work. Check `git patch-id`, not the ahead-count.

## Why `python-tree-sitter<0.26`

Under `python-tree-sitter` 0.26.0 the Solidity parser faults on contracts of
roughly 300 or more functions -- mid-traversal at higher counts, and during
interpreter finalization right at the threshold. This reproduces on *unpatched*
upstream `f7e19d3`, so it is not caused by the patches above. 0.26.0 is the
only 0.26.x release, so there is nothing newer to move to.

Upstream's own `uv.lock` pins `tree-sitter ~=0.25.0` even though
`pyproject.toml` nominally allows `<0.27`. The
[`python-tree-sitter025`](../python-tree-sitter025/) recipe in this repository
satisfies the constraint.

## Why `arch=('x86_64')`

The vendored `circom` and `masm` tree-sitter grammars normally compile
themselves on first use, shelling out to `cc` and writing
`_binding<EXT_SUFFIX>.so` next to the installed module -- that is, into
`/usr/lib/python3.x/site-packages`. Under a packaged install that fails
outright for non-root users and would leave files in `/usr` that pacman does
not own, so `build()` compiles them ahead of time.

Two consequences: the package ships compiled extensions and cannot be `any`,
and the `.so` filename embeds `EXT_SUFFIX`, so it needs a rebuild on every
Python minor version bump.

Precompiling also removes a race. Left to itself, every `pytest-xdist` worker
triggers the auto-build concurrently and they truncate the shared `.so`.

## Host tuning

`build()` compiles the two grammars with `-O3 -march=znver4 -flto`. The
upstream `-O2` is hardcoded inside a Python function, so `makepkg.conf`
`CFLAGS` cannot reach it and `build()` calls `cc` directly. The `-Wl,-z,relro,-z,now`
flags restore the full RELRO that a bare `cc` call would otherwise drop.

> [!IMPORTANT]
> `-march=znver4` makes the two grammar extensions machine-local. Change it to
> `-march=x86-64-v3` before building for a host that is not Zen 4.

## Build

Every runtime dependency comes from the AUR or from this repository, so a
clean-chroot `pkgctl build` cannot resolve them. Install
[`python-tree-sitter025`](../python-tree-sitter025/) first, then let paru
resolve the rest:

```bash
(
  cd ../python-tree-sitter025 &&
    makepkg -si --needed --force
) &&
  pacman -T 'python-tree-sitter<0.26' &&
  paru -Bi .
```

`pacman -T` must print nothing.

## Verification performed

- `1245 passed, 0 failed` via `check()` (`pytest -n auto`, roughly 6.3 s on 24 threads).
- `namcap` clean on both the `PKGBUILD` and the built archive.
- `pacman -Qkk trailmark-git`: 520 files, 0 altered.
- circom and masm parsed as a non-root user with `cc` shadowed by a failing
  stub, confirming no runtime compilation and no unowned files under `/usr`.
- The Solidity state web verified end-to-end against the installed package:
  inherited state produces `STATE_VARIABLE` nodes with cross-file `READS` and
  `WRITES` edges.
- KAT golden fixtures were not regenerated. They passed unmodified, so the
  fixture rewrites in `0001` are upstream's numbers.

## Not verified

- No clean-chroot build; the dependency graph is AUR-local.
- The 0.26.0 fault is characterised observationally. It was not root-caused
  inside the C binding and has not been reported upstream.
- `pytest -n auto` is the only measured performance win. The `-O3`, `znver4`
  and `-flto` grammar flags are unmeasured; Trailmark is close to pure Python.
- `examples/` installs to `/usr/share/doc/trailmark/examples` and is never
  exercised by `check()`.

> [!TIP]
> A `uv tool install trailmark` puts `~/.local/bin/trailmark` ahead of
> `/usr/bin/trailmark` on `PATH`, which silently shadows this package with an
> unpatched build. `uv tool uninstall trailmark` clears it.
