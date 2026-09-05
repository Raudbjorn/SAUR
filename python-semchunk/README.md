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

Restore a `<4.0.0` pin if those fixture tests ever start failing.
