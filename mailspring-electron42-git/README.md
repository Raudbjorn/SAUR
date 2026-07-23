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
- `provides`: `mailspring=<upstream-major>.<upstream-minor>`
- `conflicts`: `mailspring`, `mailspring-git`

The application paths are derived from `_appname` (the installed name) rather
than `${pkgname%-git}`. Deriving from the package name would yield
`mailspring-electron42`, which is incorrect for both the installed binary and
the `/usr/lib/mailspring` resource tree that Mailspring itself expects.

## Runtime requirements

- `electron42` — provides the system Electron 42 binary
  (`/usr/lib/electron42/electron42`) that loads `app.asar` and the bundled
  native modules.
- `db5.3` — Berkeley DB libraries Mailspring links against.

The recipe forces `package.json` and `app/build/build.js` to advertise
`SYSTEM_ELECTRON_VERSION` (the installed Electron 42 binary's reported
version) so electron-builder recompiles native modules against the system
runtime. The resulting native modules are expected to be ABI 146 (Electron 42).

## Deterministic registries

`_set_build_env()` is intentionally minimal: it sets the system Electron path,
caches the reported version, pins `HOME` and `NPM_CONFIG_CACHE` under
`${srcdir}`, and configures `NPM_CONFIG_MAXSOCKETS=32`. There is **no**
`ipinfo.io/country` probe and **no** fallback to `npmmirror.com` /
`registry.npmmirror.com`. The recipe uses the standard public npm registry.

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
git diff PKGBUILD .SRCINFO mailspring.sh README.md
```

Always inspect the diff before committing the regenerated metadata.
