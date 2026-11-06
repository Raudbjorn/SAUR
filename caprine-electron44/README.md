# caprine-electron44

[Caprine](https://github.com/sindresorhus/caprine) 2.61.0 packaged for the
system `electron44` runtime. Derived from the AUR `caprine` recipe (which pins
`electron39`). It provides and conflicts with `caprine` while keeping
Caprine's standard executable, desktop entry, and `/usr/lib/caprine` paths.

## Differences from AUR `caprine`

| Change | Effect |
| --- | --- |
| `electron39` → `electron44` | Newest Electron in `[extra]` at the time of packaging. |
| `npm-check-updates` dropped from `dependencies` | Upstream lists it as a runtime dependency, but `source/` never imports it. It pulled pacote, sigstore, node-gyp, and cacache into the app archive. `app.asar` shrinks from 23 MB to 7.8 MB. |
| `do-not-disturb` helper deleted in `package()` | A 9.6 MB macOS Mach-O executable in `app.asar.unpacked`. `source/index.ts` spawns it only behind `is.macos`. The JS module stays because it is imported unconditionally. |
| `_update_deps=1` | Deletes upstream's `package-lock.json` so npm resolves the newest versions allowed by the semver ranges in `package.json`. Set it to `0` for a lockfile-exact build. |
| `npm_config_cache` under `$srcdir` | Keeps npm from writing to `~/.npm`, per the [packaging guide](../docs/packaging-guide.md). |
| `--no-audit --no-fund --maxsockets=48`, `-c.npmRebuild=false` | Skips the audit request, allows more parallel downloads, and skips electron-builder's native-module rebuild check; the app has no native modules. |

Package size drops from 7.1 MB to 1.5 MB. Build time is dominated by
`npm install` network traffic. No CPU-specific flags apply: the package is
`arch=any`, with no native code.

## Floating dependencies

`_update_deps=1` makes the build non-reproducible. Two builds on different days
can resolve different transitive versions. Major-version updates are not
applied: `electron-store` 12 and `element-ready` 9 are ESM-only and do not
compile under Caprine's CommonJS TypeScript build.

The devDependency `electron@^29` still supplies the TypeScript typings, so
`tsc` type-checks against the Electron 29 API while the app runs on Electron 44.
APIs that Electron 44 removed can only show up at runtime.

## Verification

Run Caprine with a temporary `XDG_CONFIG_HOME` so the smoke test never touches
a live Messenger profile:

```bash
env -u WAYLAND_DISPLAY -u DISPLAY XDG_CONFIG_HOME="$(mktemp -d)" \
  ELECTRON_ENABLE_LOGGING=1 timeout 20 \
  xvfb-run -a electron44 --ozone-platform=x11 /usr/lib/caprine/app.asar
```

The log should show `https://www.messenger.com/login/` loading, with no
`Uncaught`, `TypeError`, or `Cannot find module` lines. Electron 44 logs one
deprecation warning (`session.getAllExtensions`), which is expected.

`namcap` reports `Dependency included, but may not be needed ('electron44')`.
That is a false positive: the `/usr/bin/caprine` launcher execs `electron44` by
name.

## Update

Rebase on the current AUR `caprine` recipe, keep the Electron 44 and
size-reduction changes, regenerate `.SRCINFO`, rebuild, and repeat the
isolated smoke test. When a newer `electronNN` lands in `[extra]`, rename the
package and update `_electron` together.

## Rollback

Install AUR `caprine` (or `caprine-bin`). pacman replaces this package through
the `conflicts` entry.
