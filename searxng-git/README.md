# searxng-git

SearXNG built from `master` into a bundled virtualenv, served by granian under
systemd, with a custom theme and three carried patches.

> [!WARNING]
> `arch` is `x86_64`, not `any`. The bundled venv is compiled against the host
> CPython minor version, so a Python bump requires a package rebuild.

## What this recipe adds over a stock install

| | |
| --- | --- |
| Timetable theme | A LESS override layer for the `simple` theme, rebuilt through vite. Results read as a departure board: fixed rank rail, URL before title, and a column naming every engine that returned a row. |
| Working Anna's Archive | Every public mirror answers a plain HTTP client with a DDoS-Guard 403. `searxng-annas-ddg-refresh` mints clearance through a local FlareSolverr on a timer and the engine replays it. |
| BM25 reranking | A BM25F + RRF pass over the merged result set, with quoted-phrase and `+required` term boosting. |
| Per-machine secret key | `searxng-git.install` replaces the upstream `server.secret_key` placeholder on install and upgrade, so no key is baked into a shared artifact. |

## Patches

| Patch | Why |
| --- | --- |
| `annas-archive-ddg-clearance.patch` | Replays a DDoS-Guard cookie set from a JSON file. The clearance is bound to the user agent it was issued to, and `/search` bounces once to `&check=1`, which online engines do not follow because `allow_redirects` defaults to `False`. |
| `annas-archive-none-fields.patch` | Upstream calls `extract_text(allow_none=True)` and lets `None` reach `content` and `authors`, where it raises a `TypeError` that discards the whole engine response rather than one row. |
| `bm25-reranker-query-constraints.patch` | Adds quoted-phrase and `+required` term boosting to the bundled reranker. |

## Requirements beyond the declared dependencies

- **valkey** (or redis) on `127.0.0.1:6379` backs the limiter and caches.
- **FlareSolverr** on `127.0.0.1:8191` is needed only by the Anna's Archive
  engines. Without it those engines return nothing; everything else works.
  Override with `FLARESOLVERR_URL` in `searxng-annas-ddg-refresh.service`.

## Notes for anyone editing this recipe

- `build()` removes `dist/` first. The wheel glob matched two wheels once
  upstream advanced, and the stale one won.
- `prepare()` runs `git clean -xfdq`. A patch that adds files leaves them
  untracked, and `git reset` alone does not make `prepare()` idempotent.
- `settings.yml` is a `backup=` file: local edits survive upgrades and upstream
  changes arrive as `.pacnew`, never merged automatically.
- In `settings.yml`, `engines:` and `plugins:` **replace** rather than merge. A
  second top-level key of either silently discards the first, and naming a
  single plugin drops all eleven built-ins.
- Scraper engines fail silently. A 403 yields zero XPath matches, zero results
  and an empty `/stats/errors`; absence of an error is not evidence an engine
  works.
- Do not hand-edit `.SRCINFO`; regenerate with `makepkg --printsrcinfo`.

## Licence

SearXNG is AGPL-3.0-or-later, which covers the bundled BM25 reranker plugin.
Archivo ships under the OFL; see `LICENSE.archivo-ofl`.
