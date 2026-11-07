# `minimax-code-git`

Arch VCS package for [MiniMax Code](https://github.com/MiniMax-AI/minimax-code), MiniMax's terminal coding agent (`mcode`), built from upstream `main`.

The recipe started from the AUR `minimax-code` recipe by duanluan and follows upstream's own release pipeline: `pnpm install --frozen-lockfile`, `pnpm build`, `scripts/package-cli-release.mjs`, then `npm install --global` of the resulting archive into a private staging prefix.

## Deviations from upstream

- **Default region.** Upstream falls back to the China region (`agent.minimax.cn`, `api.minimaxi.com`) when none was chosen, so global (`.io`) API keys fail with `401 invalid api key`. `build()` rewrites five defaults to the global region, bundles, then reverts the edits because upstream's packager requires a clean tracked tree. The patch fails the build unless exactly five lines changed. An explicit `MAVIS_REGION=cn` or a China login still works.
- **Install location.** Files go to `/opt/minimax-code`, outside npm's global prefix, so the built-in updater leaves pacman-owned files alone. Update through `makepkg`.
- **System Node only.** `better-sqlite3` is compiled from source against `/usr` headers, so makepkg's compiler flags apply. The launchers `/usr/bin/mcode` and `/usr/bin/mcode-tools` pin `/usr/bin/node`. Rebuild after a Node major upgrade; the dependency range is `>=22.19 <27`.
- **`mcode-tools` archive.** `code-0.3.11.tgz` is fetched from the public npm registry as a checksummed `source` entry instead of being downloaded by upstream's script during the build.
- **Pruned payload.** Windows and macOS natives, the other architecture's seccomp helper, and `better-sqlite3` build intermediates are removed.

## Name collision

`provides=('minimax-code=…' 'mcode')` and `conflicts=('minimax-code')`: the AUR `minimax-code` package installs the same command.

## Validate

```bash
bash -n PKGBUILD
namcap PKGBUILD
makepkg --printsrcinfo | cmp - .SRCINFO
BUILDDIR=/tmp/makepkg makepkg -si
mcode --version
```

`namcap PKGBUILD` reports one warning, `Reference to x86_64 should be changed to $CARCH`. It comes from the `case "${CARCH}"` arm that picks the seccomp directory to drop, and is intentional.

## Not claimed

- No clean-chroot (`pkgctl build`) build has been run; dependency completeness is unproven.
- Only `x86_64` was built. `aarch64` is declared and the seccomp pruning branch for it is untested.
- `check()` runs `mcode --version` and a `better-sqlite3` in-memory query. It does not exercise login, the TUI, sandboxing or any model call.
- The package tracks `main`, so a rebuild can break when upstream changes; `pkgver` is derived from the nearest `v*` tag and does not match the `package.json` version (0.7.6 at the time of writing).
- The region patch matches upstream source text by regular expression and is verified only by the five-line count.
