# bitwarden-electron42

Custom SAUR package for Bitwarden Desktop using the repository `electron42`
runtime. It provides and conflicts with `bitwarden` while preserving Bitwarden's
standard executable, desktop entry, application directory, and profile paths.

## Build

```bash
pkgctl build
makepkg --printsrcinfo > .SRCINFO
```

## Verification

Before installation, load the packaged `desktop_napi.node` with Electron 42 in
Node mode and run Bitwarden with a temporary `--user-data-dir`. Never use a live
credential profile for compatibility testing.

## Update

Rebase the recipe on the current Arch `bitwarden` packaging files, retain the
Electron-42 metadata and launcher changes, regenerate `.SRCINFO`, rebuild, and
repeat the isolated smoke test.

## Rollback

Reinstall repository `bitwarden`; pacman will restore its supported Electron
runtime. Do not satisfy that dependency with a fake provider.
