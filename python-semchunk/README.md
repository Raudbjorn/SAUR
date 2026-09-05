# python-semchunk

Semantic text chunking, at upstream 4.1.1. Required by
`docling-core`'s `chunking` extra.

## Why this exists

The AUR recipe passes `--compile-bytecode 2` to `python -m installer`. That
option is argparse `action="append"`, so passing only `2` **replaces** the
`[0, 1]` default rather than adding to it: the package ships `.opt-2.pyc` and
no plain `.pyc`, and ordinary non-`-OO` imports find no cached bytecode under
read-only `/usr/lib`, recompiling on every interpreter start. This recipe
ships the Arch-standard levels 0 and 1. Nothing else is changed.

## Build

```bash
makepkg -si --needed --force
```

## Removal condition

This is a defect fix, not a preference. It should go upstream to the AUR
recipe rather than be dropped here.

## Version note

`docling-core` 2.95.0 declares `semchunk (>=2.2.0,<4.0.0)`, so 4.1.1 is
nominally out of range. The cap is advisory for this consumer: semchunk 4.0.0
made only the arguments *after* `tokenizer_or_token_counter` and `chunk_size`
keyword-only, and `docling-core` calls
`semchunk.chunkerify(tokenizer, chunk_size=...)`, which is unaffected.

Verified against behaviour rather than imports: `docling-core`'s
`tests/test_hybrid_chunker.py`, which compares chunk output against committed
fixtures, passes on 4.1.1. No pinned `python-semchunk3` package exists in the
AUR.

### Verification

Run against `docling-core` 2.95.0's own suite, with this package set installed
(`python-semchunk` 4.1.1, `python-tiktoken`, `python-transformers`, and the
four `python-tree-sitter-*` grammars):

```bash
cd docling-core-2.95.0
python -m pytest -q -n auto --import-mode=importlib \
  tests/test_hybrid_chunker.py tests/test_code_chunker.py \
  tests/test_code_chunking_strategy.py tests/test_chunk_expander.py \
  tests/test_line_chunker.py tests/test_page_chunker.py \
  tests/test_hierarchical_chunker.py
```

Result: **76 passed, 1 failed**. The single failure is the Java case in
`test_code_chunker.py`, which needs `tree-sitter-java-orchard` — a member of
`docling-core`'s `dev` dependency group, not of the `chunking` extra, and not
packaged in the AUR. Java code chunking is therefore unavailable; every other
chunking path passes.

This is deliberately not wired into `python-docling-core`'s `check()`. Doing so
would make the stack's core package unbuildable without semchunk, the four
grammars, transformers and tiktoken, inverting this repository's documented
build order — `python-docling-parse` depends on `python-docling-core`, which
would then depend on its own optional extras at build time.

Restore a `<4.0.0` pin if those fixture tests ever start failing.
