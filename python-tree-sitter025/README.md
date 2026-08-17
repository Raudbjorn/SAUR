# python-tree-sitter025

`python-tree-sitter` pinned to the 0.25.x series, for consumers that the 0.26.0
release breaks.

## Why this exists

The AUR ships `python-tree-sitter` 0.26.0. Under 0.26.0, parsing a Solidity
contract of roughly 300 or more functions faults:

- at higher function counts, a SIGSEGV mid-traversal inside the C binding,
  reached through `node.text`;
- right at the threshold, a fault during interpreter finalization *after* the
  parse has already returned successfully.

This reproduces on unpatched upstream Trailmark `f7e19d3`, so it is not
specific to any downstream patch. 0.26.0 is currently the only 0.26.x release,
so there is no point release to move to.

tree-sitter 0.25.2 does not exhibit the fault. Trailmark's full suite is
`1245 passed, 0 failed` against it with `python-tree-sitter-language-pack`
1.15.0. This also matches upstream Trailmark's own `uv.lock`, which pins
`tree-sitter ~=0.25.0` even though its `pyproject.toml` nominally allows
`<0.27`.

## Why a suffixed name

`provides=('python-tree-sitter=0.25.2')` with `conflicts=('python-tree-sitter')`
rather than a same-`pkgname` downgrade, so that `pacman -Syu` cannot silently
pull 0.26.0 back in.

> [!WARNING]
> This replaces `python-tree-sitter` system-wide, for the benefit of one
> consumer. The only reverse dependency observed was
> `python-tree-sitter-language-pack`, which requires `tree-sitter>=0.23` and is
> therefore satisfied. Check `pactree -r python-tree-sitter` on your own host
> before installing.

## Build

```bash
makepkg -si --needed --force &&
  pacman -T 'python-tree-sitter<0.26'
```

`pacman -T` must print nothing.

## Removal condition

Drop this recipe once `python-tree-sitter` 0.26.1 or newer is available and the
large-Solidity reproducer passes against it:

```bash
python - <<'PY'
from pathlib import Path
Path("/tmp/large.sol").write_text(
    "pragma solidity ^0.8.0; contract Large {\n"
    + "".join(
        f"function f{i}() external pure returns(uint) {{ return {i}; }}\n"
        for i in range(500)
    )
    + "}\n"
)
PY
python -X faulthandler -c \
  "from trailmark.parse import parse_file; print(len(parse_file('/tmp/large.sol','solidity').nodes))"
```

Expect `502` and exit status 0. Under 0.26.0 this exits 139.

## Not verified

The fault is characterised observationally. It was not root-caused inside the C
binding and has not been reported upstream, so 0.25.2 is a known-good pin
rather than a fix.
