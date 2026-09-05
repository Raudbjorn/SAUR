# mailspring-electron42-git

Mailspring Git packaged for the system Electron 42 runtime. Custom SAUR recipe
that tracks the upstream `Foundry376/Mailspring` Git history while rebuilding
native modules against the installed Electron 42 binary.

## Identity

- `pkgname`: `mailspring-electron42-git`
- Installed executable: `/usr/bin/mailspring`
- Installed library: `/usr/lib/mailspring/` (contains `app.asar` and bundled
  resources)
- Desktop entry: `/usr/share/applications/mailspring.desktop`
- Metainfo: `/usr/share/metainfo/mailspring.metainfo.xml`
- Icons: `/usr/share/icons/hicolor/{16,32,64,128,256,512}x{...}/apps/mailspring.png`
- `provides`: `mailspring=<upstream-major>.<upstream-minor>.<upstream-patch>`
  (`${pkgver%.r*}`, e.g. `1.23.0`)
- `conflicts`: `mailspring`, `mailspring-git`

The application paths are derived from `_appname` (the installed name) rather
than `${pkgname%-git}`. Deriving from the package name would yield
`mailspring-electron42`, which is incorrect for both the installed binary and
the `/usr/lib/mailspring` resource tree that Mailspring itself expects.

## Runtime requirements

- `electron42` — provides the system Electron 42 binary at
  `/usr/lib/electron42/electron` (invoked as the `electron42` command) that
  loads `app.asar` and the bundled native modules.
- `db5.3` — Berkeley DB libraries Mailspring links against.

The recipe forces `package.json` and `app/build/build.js` to advertise
`SYSTEM_ELECTRON_VERSION` (the installed Electron 42 binary's reported
version) so electron-builder rebuilds any remaining compiled native modules
against the system runtime. **Electron 42 is a hard requirement** — this
package does not work against any other Electron major. The database layer is
the exception to the ABI story: it is ported to libsql (see below), which
ships an ABI-stable prebuilt binding.

## Database (Turso/libsql port)

`mailspring-turso.patch` replaces upstream's `better-sqlite3` dependency with
`@libsql/client` (Turso's libsql binding, pinned to `0.17.4` in the patch):

- **No per-ABI native rebuild.** `@libsql/client` ships a prebuilt N-API
  binding (`@libsql/linux-x64-gnu/index.node`) that is ABI-stable across
  Electron/Node majors, so the database layer needs no recompilation for
  Electron 42's ABI.
- **Read-only enforcement.** libsql exposes no read-only connection flag on
  its JS surface, so the read-only contract is enforced with SQLite's own
  `PRAGMA query_only = ON`, applied after the mutating setup PRAGMAs (WAL,
  page_size, cache_size, synchronous) and held for the connection's lifetime.
- **Lock handling.** The local file client's `timeout` (busy_timeout) option
  handles SQLite lock waits; `DatabaseStore`'s exponential backoff retries
  transient "database is locked" errors at the application level.

Refresh the patch's `sha256sum` and regenerate `.SRCINFO` whenever the patch
is rebased onto a newer upstream revision.

## Deterministic registries

`_set_build_env()` sets the system Electron path, caches the reported version,
pins `HOME` and `NPM_CONFIG_CACHE` under `${srcdir}`, and configures
`NPM_CONFIG_MAXSOCKETS=32`. It also pins `NPM_CONFIG_REGISTRY` to the public
`https://registry.npmjs.org/` and points `npm_config_userconfig` /
`npm_config_globalconfig` at `/dev/null` so an inherited user or global
`.npmrc` cannot redirect downloads. There is **no** geolocation probe and
**no** fallback to the upstream `npmmirror.com` / `registry.npmmirror.com`
mirrors.

## Build commands

```bash
makepkg --printsrcinfo > .SRCINFO   # regenerate metadata after editing PKGBUILD
bash -n PKGBUILD                    # bash syntax
namcap PKGBUILD                     # static lint
pkgctl build                        # clean-chroot build
```

Always regenerate `.SRCINFO` after editing the recipe; never hand-edit it.

## Icon sizes

The package installs six icon sizes, matching Mailspring's upstream
`app/build/resources/linux/icons/`:

- `16x16`
- `32x32`
- `64x64`
- `128x128`
- `256x256`
- `512x512`

## Isolated smoke testing

Before configuring any mail account, verify the launcher runs against the
system Electron 42 binary by pointing `XDG_CONFIG_HOME` at an empty directory:

```bash
XDG_CONFIG_HOME="$(mktemp -d)" mailspring --version
```

A successful `--version` exit confirms the launcher, the system Electron
binary, and the bundled `app.asar` are wired correctly with no configuration
state.

## Rollback

To revert to the AUR `mailspring-git` recipe (Electron 41):

```bash
sudo pacman -Rns mailspring-electron42-git
paru -Bi mailspring-git
```

`mailspring-git` and `mailspring-electron42-git` declare a `conflicts`
relationship, so only one can be installed at a time.

## Maintenance

The package version is taken from `git describe` against the upstream
`Foundry376/Mailspring` Git history. To update:

```bash
makepkg --verifysource    # refresh the local source clone
makepkg --printsrcinfo > .SRCINFO
git diff PKGBUILD .SRCINFO mailspring.sh mailspring-turso.patch README.md
```

Always inspect the diff before committing the regenerated metadata.
