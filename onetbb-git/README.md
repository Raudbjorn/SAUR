# onetbb-git

Source-built [oneTBB](https://github.com/uxlfoundation/oneTBB) (oneAPI Threading Building Blocks) from a pinned upstream `master` commit, plus one downstream patch.

## Source pin

- Upstream commit `af14bb5` (uxlfoundation/oneTBB `master`, 2026-10-16), reporting version 2023.2.0 and `libtbb.so.12.20`.
- The commit is pinned because the patch is generated against that exact tree. Bump the pin and regenerate the patch together.
- The old `oneapi-src/onetbb` URL redirects; this recipe uses the current `uxlfoundation` URL.

## Patch: `0001-concurrent-queue-stateful-allocator.patch`

Port of YexuanXiao's [uxlfoundation/oneTBB#1520](https://github.com/uxlfoundation/oneTBB/pull/1520) (closed unmerged; the reason is not recorded on the PR). `concurrent_queue` and `concurrent_bounded_queue` previously ignored `propagate_on_container_copy_assignment` / `_move_assignment`: with propagation off, the target queue still took the source's allocator.

Port notes:

- Two of the three files apply unchanged. `concurrent_queue.h` needed a hand merge because upstream added `my_capacity = other.my_capacity;` to the bounded queue's assignment operators; both are kept.
- Verified before packaging: `conformance_concurrent_queue`, `test_concurrent_queue` and `test_concurrent_queue_whitebox` pass, and a stateful-allocator check (propagation on and off, both queue types, under ASan/UBSan) fails on unpatched `master` and passes patched.
- The full upstream suite was **not** run, and `check()` is disabled.

## Build choices

- `TCM_BUILD=OFF`: upstream's Thread Composability Manager target is built with `-Werror` and its own `-D_FORTIFY_SOURCE=2`, which clashes with makepkg's `=3`; `TBB_STRICT=OFF` does not cover it. The repository `onetbb` package omits TCM as well.
- `TBB4PY_BUILD=ON` builds the Python bindings. Upstream's `python_build` target runs `pip install --prefix build`; the recipe sets `PIP_IGNORE_INSTALLED=1` so pip never uninstalls an already-installed `tbb` from the live `site-packages`, and installs with `cmake --install` so that target is not re-run under fakeroot.
- `direct_url.json` is removed from the dist-info because it records `$srcdir`.

## Replaces the repository `onetbb`

`provides` `onetbb`, `tbb`, `intel-tbb`, `libtbb.so=12-64` and `libtbbmalloc.so=2-64`; `conflicts` with `onetbb`, `tbb` and `intel-tbb`. There is deliberately no `replaces`, so `pacman -Syu` never swaps it in on its own.

Compared with the repository package, `blocked_rangeNd.h` (deprecated upstream, removed on `master`) is gone; use `blocked_nd_range.h`. No installed package referenced it when this was packaged.

namcap reports a false positive for the package depending on its own `onetbb` provides.
