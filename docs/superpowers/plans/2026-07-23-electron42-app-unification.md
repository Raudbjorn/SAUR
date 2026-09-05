# Electron 42 Application Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, install, and maintain custom Bitwarden and Mailspring packages that share Electron 42, then remove Electron 39 and Electron 41 only after isolated compatibility tests pass.

**Architecture:** Add two package-scoped recipes to SAUR. Each custom package preserves the upstream application's paths and stable package identity while explicitly targeting Electron 42. Build artifacts are validated before installation; native modules and renderer startup are tested against temporary profiles before the old Electron runtimes are removed.

**Tech Stack:** Arch Linux PKGBUILD/makepkg, pkgctl clean chroots, namcap, Bash launchers, Electron 42.7.x, Node native modules, npm, Rust, Git.

## Global Constraints

- Package names are `bitwarden-electron42` and `mailspring-electron42-git`.
- Both packages must depend on the real `electron42` package; do not introduce fake Electron 39/41 providers.
- Preserve `/usr/bin/bitwarden-desktop`, `/usr/lib/bitwarden`, `/usr/bin/mailspring`, `/usr/lib/mailspring`, and both existing desktop-entry names.
- Bitwarden must retain its process-isolation preload library and native-messaging patches.
- Mailspring must rebuild every native module for `NODE_MODULE_VERSION` 146; installed Electron-41 objects must never be copied.
- Remove the Mailspring recipe's `curl -s ipinfo.io/country` branch and use the standard registries deterministically.
- Correct the Mailspring icon loop to iterate over `_icon_sizes` and package icons at 16, 32, 64, 128, 256, and 512 pixels.
- Build and inspect both package archives before replacing either installed application.
- All application smoke tests must use temporary profiles and no live Bitwarden credentials or mail accounts.
- Keep Electron 39 and Electron 41 until both isolated smoke tests pass.
- Build as the unprivileged `svnbjrn` user. Use `ssh sveinbjorn` only for package installation and removal requiring elevation.
- Regenerate `.SRCINFO`; never edit it manually.
- Do not commit `src/`, `pkg/`, package archives, build logs, local source clones, or credentials.

---

### Task 1: Add the maintained Bitwarden Electron 42 package

**Files:**
- Create: `bitwarden-electron42/PKGBUILD`
- Create: `bitwarden-electron42/.SRCINFO`
- Create: `bitwarden-electron42/README.md`
- Create: `bitwarden-electron42/bitwarden.sh`
- Create: `bitwarden-electron42/bitwarden.desktop`
- Create: `bitwarden-electron42/messaging.main.ts.patch`
- Create: `bitwarden-electron42/native-messaging.main.ts.patch`
- Create: `bitwarden-electron42/nativelib.patch`
- Create: `bitwarden-electron42/no-sourcemaps.patch`
- Create: `bitwarden-electron42/remove-unnecessary-deps.patch`

**Interfaces:**
- Consumes: Arch's current `bitwarden` packaging repository and repository package `electron42`.
- Produces: a package archive named `bitwarden-electron42-<version>-<release>-x86_64.pkg.tar.zst` that provides `bitwarden=<version>` and launches Electron 42.

- [ ] **Step 1: Import the current Arch packaging inputs**

Run from `/home/svnbjrn/dev/projects/SAUR`:

```bash
rm -rf /tmp/bitwarden-arch-packaging
git clone --depth=1 https://gitlab.archlinux.org/archlinux/packaging/packages/bitwarden.git /tmp/bitwarden-arch-packaging
mkdir bitwarden-electron42
cp /tmp/bitwarden-arch-packaging/{PKGBUILD,bitwarden.sh,bitwarden.desktop,messaging.main.ts.patch,native-messaging.main.ts.patch,nativelib.patch,no-sourcemaps.patch,remove-unnecessary-deps.patch} bitwarden-electron42/
```

Expected: the destination contains the official recipe and all source-array files, with no nested `.git` directory.

- [ ] **Step 2: Run the pre-change metadata test and verify it fails**

Run:

```bash
cd "$(git rev-parse --show-toplevel)/bitwarden-electron42"
makepkg --printsrcinfo | awk '
  /^\s*pkgbase =/ { base=$3 }
  /^\s*depends = electron42$/ { e42=1 }
  /^\s*provides = bitwarden=/ { provides=1 }
  END { exit !(base=="bitwarden-electron42" && e42 && provides) }
'
```

Expected: nonzero exit because the imported recipe still declares `pkgbase = bitwarden` and `electron39`.

- [ ] **Step 3: Convert the PKGBUILD to a custom Electron 42 package**

Keep the imported lifecycle functions and checksum array, but make these exact metadata and path changes:

```bash
pkgname=bitwarden-electron42
_pkgname=bitwarden
pkgver=2026.3.1
pkgrel=1
_electronversion=42
pkgdesc='Bitwarden desktop packaged for the system Electron 42 runtime'
provides=("bitwarden=$pkgver")
conflicts=('bitwarden')
depends=("electron$_electronversion" 'libnotify' 'org.freedesktop.secrets' 'libxtst' 'libxss' 'libnss_nis')
```

In `source=()`, keep the Git source name `bitwarden` and replace `${pkgname}.sh` and `${pkgname}.desktop` with `${_pkgname}.sh` and `${_pkgname}.desktop`.

In `package()`, all live application paths and source filenames must use `_pkgname`:

```bash
install -vDm644 dist/linux-unpacked/resources/app.asar -t "${pkgdir}/usr/lib/${_pkgname}"
install -vDm644 build/package.json -t "${pkgdir}/usr/lib/${_pkgname}"
install -vDm755 build/desktop_proxy -t "${pkgdir}/usr/lib/${_pkgname}"
install -vDm755 desktop_native/target/release/libprocess_isolation.so -t "${pkgdir}/usr/lib/${_pkgname}"
cp -vr dist/linux-unpacked/resources/app.asar.unpacked -t "${pkgdir}/usr/lib/${_pkgname}"

for i in 16 32 64 128 256 512 1024; do
    install -vDm644 resources/icons/${i}x${i}.png \
        "${pkgdir}/usr/share/icons/hicolor/${i}x${i}/apps/${_pkgname}.png"
done
install -vDm644 resources/icon.png \
    "${pkgdir}/usr/share/icons/hicolor/1024x1024/apps/${_pkgname}.png"
install -vDm755 "${srcdir}/${_pkgname}.sh" "${pkgdir}/usr/bin/bitwarden-desktop"
install -vDm644 "${srcdir}/${_pkgname}.desktop" -t "${pkgdir}/usr/share/applications"
```

Do not change the upstream Git tag, patch order, Rust build, `electron-builder` target, process-isolation library, or native-messaging behavior.

- [ ] **Step 4: Make the launcher target Electron 42 safely**

Replace `bitwarden-electron42/bitwarden.sh` with:

```sh
#!/bin/sh
set -eu
export ELECTRON_IS_DEV=0

# Prevent credential-bearing process memory from being dumped or attached.
ulimit -c 0
export LD_PRELOAD=/usr/lib/bitwarden/libprocess_isolation.so

cd /usr/lib/bitwarden
exec electron42 /usr/lib/bitwarden/app.asar "$@"
```

Run:

```bash
bash -n bitwarden.sh
shellcheck bitwarden.sh
```

Expected: both commands exit 0.

- [ ] **Step 5: Document package maintenance and rollback**

Create `bitwarden-electron42/README.md` with these operational facts:

```markdown
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
```

- [ ] **Step 6: Regenerate metadata and rerun the static test**

Run:

```bash
makepkg --printsrcinfo > .SRCINFO
bash -n PKGBUILD
makepkg --printsrcinfo | awk '
  /^\s*pkgbase =/ { base=$3 }
  /^\s*depends = electron42$/ { e42=1 }
  /^\s*provides = bitwarden=/ { provides=1 }
  /^\s*conflicts = bitwarden$/ { conflicts=1 }
  END { exit !(base=="bitwarden-electron42" && e42 && provides && conflicts) }
'
namcap PKGBUILD
```

Expected: syntax and metadata assertions pass. Review every namcap warning rather than suppressing it.

- [ ] **Step 7: Build and inspect the package**

Run:

```bash
pkgctl build
bitwarden_pkg=$(makepkg --packagelist)
namcap "$bitwarden_pkg"
bsdtar -tf "$bitwarden_pkg" | sort
```

Expected archive content includes:

```text
usr/bin/bitwarden-desktop
usr/lib/bitwarden/app.asar
usr/lib/bitwarden/libprocess_isolation.so
usr/lib/bitwarden/app.asar.unpacked/node_modules/@bitwarden/desktop-napi/desktop_napi.node
usr/share/applications/bitwarden.desktop
```

- [ ] **Step 8: Commit the Bitwarden package**

```bash
git add bitwarden-electron42/PKGBUILD \
  bitwarden-electron42/.SRCINFO \
  bitwarden-electron42/README.md \
  bitwarden-electron42/bitwarden.sh \
  bitwarden-electron42/bitwarden.desktop \
  bitwarden-electron42/messaging.main.ts.patch \
  bitwarden-electron42/native-messaging.main.ts.patch \
  bitwarden-electron42/nativelib.patch \
  bitwarden-electron42/no-sourcemaps.patch \
  bitwarden-electron42/remove-unnecessary-deps.patch
git commit -m "feat: package Bitwarden for Electron 42"
```

### Task 2: Add the maintained Mailspring Electron 42 package

**Files:**
- Create: `mailspring-electron42-git/PKGBUILD`
- Create: `mailspring-electron42-git/.SRCINFO`
- Create: `mailspring-electron42-git/README.md`
- Create: `mailspring-electron42-git/mailspring.sh`

**Interfaces:**
- Consumes: current AUR `mailspring-git` recipe, Mailspring upstream Git, repository `electron42`, and repository `db5.3`.
- Produces: `mailspring-electron42-git-<version>-x86_64.pkg.tar.zst`, providing `mailspring=<version>` with native modules built for ABI 146.

- [ ] **Step 1: Import the current AUR recipe and launcher**

Run from the SAUR root:

```bash
rm -rf /tmp/mailspring-git-aur
git clone --depth=1 https://aur.archlinux.org/mailspring-git.git /tmp/mailspring-git-aur
mkdir mailspring-electron42-git
cp /tmp/mailspring-git-aur/{PKGBUILD,mailspring.sh} mailspring-electron42-git/
```

Expected: only `PKGBUILD` and `mailspring.sh` are imported; no AUR `.git` directory enters SAUR.

- [ ] **Step 2: Prove the imported recipe violates the design**

Run:

```bash
cd "$(git rev-parse --show-toplevel)/mailspring-electron42-git"
python -c 'import subprocess; s=subprocess.run(["makepkg","--printsrcinfo"],check=True,text=True,capture_output=True).stdout; assert "\tdepends = electron42\n" not in s'
python -c 'from pathlib import Path; s=Path("PKGBUILD").read_text(); assert "ipinfo.io/country" in s'
python -c 'from pathlib import Path; s=Path("PKGBUILD").read_text(); assert "for _icon_size in \"${_icon_size[@]}\"" in s'
```

Expected: all three commands exit 0, proving the imported recipe targets Electron 41, performs the geolocation request, and contains the singular-array icon-loop defect.

- [ ] **Step 3: Refactor package identity and source-directory handling**

Use these exact top-level identities:

```bash
pkgname=mailspring-electron42-git
_pkgname=Mailspring
_appname=mailspring
_srcname=mailspring.git
_electronversion=42
_nodeversion=22
pkgrel=1
pkgdesc='Mailspring Git packaged for the system Electron 42 runtime'
conflicts=('mailspring' 'mailspring-git')
provides=("mailspring=${pkgver%.r*}")
depends=('electron42' 'db5.3')
source=(
    "${_srcname}::git+https://github.com/Foundry376/Mailspring.git"
    "${_appname}.sh"
)
sha256sums=('SKIP' 'SKIP')
```

Use `_srcname` consistently in `pkgver()`, `prepare()`, and `build()`:

```bash
cd "${srcdir}/${_srcname}"
```

Use `_appname` for installed executable, library, desktop, metainfo, and icon paths. Do not derive application paths from `${pkgname%-git}` because that would produce `mailspring-electron42`.

- [ ] **Step 4: Remove the geolocation-dependent registry branch**

Make `_set_build_env()` deterministic:

```bash
_set_build_env() {
    export ELECTRON_DIST="/usr/lib/electron${_electronversion}"
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    export SYSTEM_ELECTRON_VERSION="$(electron${_electronversion} -v | sed 's/v//g')"
    export HOME="${srcdir}/.electron-gyp"
    export NPM_CONFIG_CACHE="${srcdir}/.npm_cache"
    export NPM_CONFIG_MAXSOCKETS=32
    export NPM_CONFIG_REGISTRY="https://registry.npmjs.org/"
    export npm_config_userconfig=/dev/null
    export npm_config_globalconfig=/dev/null
}
```

There must be no request to `ipinfo.io`, no geography-dependent registry selection, and no fallback that silently changes registries.

- [ ] **Step 5: Preserve system-Electron targeting and rebuild native modules**

In `prepare()`, substitute the stable application name and Electron major into `mailspring.sh`, then force the build metadata to the installed Electron 42 version:

```bash
sed -i -e "
    s/@electronversion@/${_electronversion}/g
    s/@appname@/${_appname}/g
    s/@runname@/app.asar/g
    s/@cfgdirname@/${_pkgname}/
    s/@options@/env ELECTRON_OZONE_PLATFORM_HINT=auto --password-store=\"gnome-libsecret\"/g
" "${srcdir}/${_appname}.sh"

sed -i "/await createRpmInstaller/d" app/build/build.js
sed -i "s/execstack --clear-execstack//g" app/script/mkdeb
sed -i "s/\"electron\": \"[^\"]*\"/\"electron\": \"${SYSTEM_ELECTRON_VERSION}\"/g" package.json
sed -i "s/tmpdir,/tmpdir,\n    electronDist: process.env.ELECTRON_DIST,/" app/build/build.js
NODE_ENV=development npm install
```

Retain the recipe's production build so Electron Builder recompiles native dependencies against the configured Electron distribution:

```bash
NODE_ENV=production npm run build
```

The post-build package gate in Task 3, not the build command alone, proves ABI 146 compatibility.

- [ ] **Step 6: Fix and test the icon packaging loop**

Use this exact package block:

```bash
_icon_sizes=(16 32 64 128 256 512)
for _icon_size in "${_icon_sizes[@]}"; do
    install -Dm644 \
        "${srcdir}/${_srcname}/app/build/resources/linux/icons/${_icon_size}.png" \
        "${pkgdir}/usr/share/icons/hicolor/${_icon_size}x${_icon_size}/apps/${_appname}.png"
done
```

The loop variable is singular; the array reference is plural.

- [ ] **Step 7: Keep the launcher on Electron 42 and standard paths**

Retain the imported launcher template placeholders. The prepared package must resolve them to:

```bash
_APPDIR="/usr/lib/mailspring"
_RUNNAME="${_APPDIR}/app.asar"
```

The flag source list must contain:

```bash
"${XDG_CONFIG_HOME}/electron42-flags.conf"
```

The final command must be:

```bash
exec electron42 "${flags[@]}" "${_SANDBOX_ARG[@]}" "${_RUNNAME}" "$@"
```

Run `bash -n mailspring.sh` and `shellcheck mailspring.sh` before building.

- [ ] **Step 8: Install files under the stable application identity**

The `package()` function must use:

```bash
install -Dm755 "${srcdir}/${_appname}.sh" "${pkgdir}/usr/bin/${_appname}"
install -Dm755 -d "${pkgdir}/usr/lib/${_appname}"
local _app_dir
_app_dir="$(_get_app_dir)"
cp -a "${_app_dir}/resources/"* "${pkgdir}/usr/lib/${_appname}/"
sed "s/${_pkgname}.desktop/${_appname}.desktop/g" -i \
    "${srcdir}/${_srcname}/app/dist/${_appname}.metainfo.xml"
install -Dm644 "${srcdir}/${_srcname}/app/dist/${_pkgname}.desktop" \
    "${pkgdir}/usr/share/applications/${_appname}.desktop"
install -Dm644 "${srcdir}/${_srcname}/app/dist/${_appname}.metainfo.xml" \
    -t "${pkgdir}/usr/share/metainfo"
```

Include the corrected icon loop from Step 6 in the same function.

- [ ] **Step 9: Document maintenance and rollback**

Create `mailspring-electron42-git/README.md` documenting:

- the custom package identity and stable Mailspring paths;
- Electron 42 and native ABI 146 as hard requirements;
- deterministic standard-registry behavior;
- `pkgctl build`, `.SRCINFO`, and namcap commands;
- the six required icon sizes;
- isolated `XDG_CONFIG_HOME` smoke testing with no mail account;
- rollback via AUR `mailspring-git`, which restores Electron 41.

- [ ] **Step 10: Generate checksums and verify static requirements**

Run:

```bash
updpkgsums
makepkg --printsrcinfo > .SRCINFO
bash -n PKGBUILD
namcap PKGBUILD
python -c 'import subprocess; s=subprocess.run(["makepkg","--printsrcinfo"],check=True,text=True,capture_output=True).stdout; assert "\tdepends = electron42\n" in s'
python -c 'from pathlib import Path; assert "ipinfo.io" not in Path("PKGBUILD").read_text()'
python -c 'from pathlib import Path; assert "for _icon_size in \"${_icon_sizes[@]}\"" in Path("PKGBUILD").read_text()'
```

Expected: every command exits 0 and `.SRCINFO` names `mailspring-electron42-git`.

- [ ] **Step 11: Build the Mailspring package**

Run:

```bash
pkgctl build
mailspring_pkg=$(makepkg --packagelist)
namcap "$mailspring_pkg"
bsdtar -tf "$mailspring_pkg" | sort
```

Expected: build succeeds using Electron 42 and the archive contains `usr/bin/mailspring`, `usr/lib/mailspring/app.asar`, `usr/lib/mailspring/app.asar.unpacked/node_modules/@libsql/linux-x64-gnu/index.node`, the desktop file, metainfo, and all six icon sizes.

- [ ] **Step 12: Commit the Mailspring package**

```bash
git add mailspring-electron42-git/PKGBUILD \
  mailspring-electron42-git/.SRCINFO \
  mailspring-electron42-git/README.md \
  mailspring-electron42-git/mailspring.sh
git commit -m "feat: package Mailspring for Electron 42"
```

### Task 3: Gate package archives on Electron 42 compatibility

**Files:**
- Verify: `bitwarden-electron42/*.pkg.tar.zst`
- Verify: `mailspring-electron42-git/*.pkg.tar.zst`
- Verify: `/var/cache/pacman/pkg/electron42-42.7.1-1-x86_64.pkg.tar.zst`

**Interfaces:**
- Consumes: both package archives from Tasks 1 and 2 and the cached repository Electron 42 package.
- Produces: evidence that the packaged native modules load under ABI 146 and the expected icons and launchers exist.

- [ ] **Step 1: Create an isolated archive-inspection root**

Run:

```bash
probe_root=$(mktemp -d /tmp/electron42-package-gate.XXXXXX)
mkdir -p "$probe_root/electron" "$probe_root/bitwarden" "$probe_root/mailspring"
bsdtar -xf /var/cache/pacman/pkg/electron42-42.7.1-1-x86_64.pkg.tar.zst -C "$probe_root/electron"
bsdtar -xf "$(cd bitwarden-electron42 && makepkg --packagelist)" -C "$probe_root/bitwarden"
bsdtar -xf "$(cd mailspring-electron42-git && makepkg --packagelist)" -C "$probe_root/mailspring"
```

Expected: all three roots populate without writing to the live filesystem.

- [ ] **Step 2: Verify the Electron target ABI**

Run:

```bash
ELECTRON_RUN_AS_NODE=1 "$probe_root/electron/usr/lib/electron42/electron" \
  -p 'JSON.stringify({electron:process.versions.electron,node:process.versions.node,modules:process.versions.modules,napi:process.versions.napi})'
```

Expected JSON includes `"modules":"146"`, `"napi":"10"`, and an Electron 42 version.

- [ ] **Step 3: Load Bitwarden's packaged native module**

Run:

```bash
bitwarden_node="$probe_root/bitwarden/usr/lib/bitwarden/app.asar.unpacked/node_modules/@bitwarden/desktop-napi/desktop_napi.node"
ELECTRON_RUN_AS_NODE=1 "$probe_root/electron/usr/lib/electron42/electron" \
  -e "require(${bitwarden_node@Q}); console.log('bitwarden desktop_napi loaded')"
ldd "$bitwarden_node"
```

Expected: `bitwarden desktop_napi loaded`, exit 0, and no `not found` library from `ldd`.

- [ ] **Step 4: Load Mailspring's packaged `@libsql/client` native module**

Run:

```bash
mailspring_node="$probe_root/mailspring/usr/lib/mailspring/app.asar.unpacked/node_modules/@libsql/linux-x64-gnu/index.node"
ELECTRON_RUN_AS_NODE=1 "$probe_root/electron/usr/lib/electron42/electron" \
  -e "require(${mailspring_node@Q}); console.log('mailspring @libsql/linux-x64-gnu loaded')"
ldd "$mailspring_node"
```

Expected: `mailspring @libsql/linux-x64-gnu loaded`, exit 0, no `NODE_MODULE_VERSION` error, no `ERR_DLOPEN_FAILED`, and no missing library.

- [ ] **Step 5: Verify Mailspring's complete icon set**

Run:

```bash
mailspring_pkg=$(cd mailspring-electron42-git && makepkg --packagelist)
for size in 16 32 64 128 256 512; do
  bsdtar -tf "$mailspring_pkg" | awk -v path="usr/share/icons/hicolor/${size}x${size}/apps/mailspring.png" '$0 == path { found=1 } END { exit !found }'
done
```

Expected: all six exact archive paths are present.

- [ ] **Step 6: Verify package metadata and launchers**

Run:

```bash
pacman -Qip "$(cd bitwarden-electron42 && makepkg --packagelist)"
pacman -Qip "$(cd mailspring-electron42-git && makepkg --packagelist)"
awk 'index($0, "exec electron42") { found=1 } END { exit !found }' "$probe_root/bitwarden/usr/bin/bitwarden-desktop"
awk 'index($0, "exec electron42") { found=1 } END { exit !found }' "$probe_root/mailspring/usr/bin/mailspring"
```

Expected: both packages depend on `electron42`, provide their stable identities, conflict with originals, and invoke Electron 42.

- [ ] **Step 7: Remove only the temporary inspection root**

```bash
rm -rf -- "$probe_root"
```

Expected: the exact `mktemp` directory is removed; package archives remain.

### Task 4: Install custom packages and run isolated renderer smoke tests

**Files:**
- Install: built Bitwarden package archive
- Install: built Mailspring package archive
- Install: repository `electron42`
- Preserve: live `~/.config/Bitwarden` and `~/.config/Mailspring` data

**Interfaces:**
- Consumes: package archives that passed Task 3.
- Produces: installed custom applications proven to start isolated renderers under Electron 42 while Electron 39/41 remain available for rollback.

- [ ] **Step 1: Capture package-database and rollback baselines**

Run:

```bash
pacman -Dk > /tmp/pacman-Dk.before-electron42.txt 2>&1 || true

# Record the installed rollback baseline (versions only; no account,
# mail, or credential data is read).
pacman -Q bitwarden mailspring-git electron39 electron41-bin \
  | tee /tmp/rollback-installed.before-electron42.txt

# Confirm each rollback artifact is re-obtainable before replacing it:
# either a cached package archive or a resolvable repo/AUR source.
ls -l /var/cache/pacman/pkg/bitwarden-*.pkg.tar.zst \
      /var/cache/pacman/pkg/electron39-*.pkg.tar.zst \
      /var/cache/pacman/pkg/electron41-bin-*.pkg.tar.zst \
      /var/cache/pacman/pkg/mailspring-git-*.pkg.tar.zst 2>&1 \
  | tee /tmp/rollback-cache.before-electron42.txt
pacman -Si bitwarden electron39 electron42 db5.3
paru -Si mailspring-git electron41-bin
```

Every rollback target — Bitwarden, Electron 39, Electron 41 (`electron41-bin`),
and the AUR Mailspring recipe — must resolve to a cached archive or an
installable source before proceeding. The commands above read only package
metadata; they do not open mail or password-manager data.

- [ ] **Step 2: Ensure package managers and applications are quiescent**

Run:

```bash
pgrep -af 'pacman|paru|yay|pamac'
pgrep -af 'bitwarden|mailspring'
```

Expected: no package transaction. If either application is active, close it normally; use `TERM` only if it does not exit.

- [ ] **Step 3: Dry-run the replacement transaction**

Resolve exact archive paths:

```bash
_saur_root=$(git rev-parse --show-toplevel)
bitwarden_pkg_local=$(cd "$_saur_root/bitwarden-electron42" && makepkg --packagelist)
mailspring_pkg_local=$(cd "$_saur_root/mailspring-electron42-git" && makepkg --packagelist)
electron42_pkg=/var/cache/pacman/pkg/electron42-42.7.1-1-x86_64.pkg.tar.zst

# `pacman -U` runs on sveinbjorn, so the two locally built archives must be
# staged to a path sveinbjorn can read. electron42_pkg already lives in
# sveinbjorn's package cache and is used in place.
#
# The `sveinbjorn` ssh alias authenticates as root (`User root` in
# ~/.ssh/config). That is what makes the root-owned package cache writable
# for scp and lets the later `pacman -U` run without sudo; staging into the
# cache also keeps both archives available as rollback sources. Fail here,
# not mid-transfer, if the alias ever stops resolving to a user that can
# write there.
_stage=/var/cache/pacman/pkg
ssh sveinbjorn test -w "${_stage}"
for _p in "$bitwarden_pkg_local" "$mailspring_pkg_local"; do
    zstd -t "$_p"                                      # integrity-check the local archive
    scp "$_p" "sveinbjorn:${_stage}/"
    ssh sveinbjorn test -r "${_stage}/$(basename "$_p")"   # confirm readable on sveinbjorn
done
bitwarden_pkg="${_stage}/$(basename "$bitwarden_pkg_local")"
mailspring_pkg="${_stage}/$(basename "$mailspring_pkg_local")"
```

Run through elevation:

```bash
ssh sveinbjorn pacman -U --print "$electron42_pkg" "$bitwarden_pkg" "$mailspring_pkg"
```

Expected targets: Electron 42 and the two custom packages. The real transaction may replace conflicting `bitwarden` and `mailspring-git`; it must not select unrelated applications or Electron 39/41 for removal.

- [ ] **Step 4: Install the three validated archives**

Run the same exact paths without `--print` through an interactive elevated command:

```bash
ssh sveinbjorn pacman -U "$electron42_pkg" "$bitwarden_pkg" "$mailspring_pkg"
```

Accept replacement of `bitwarden` and `mailspring-git`. Abort if pacman proposes removing anything else.

- [ ] **Step 5: Verify installed package wiring before launch**

Run:

```bash
pacman -Q bitwarden-electron42 mailspring-electron42-git electron42 electron39 electron41-bin
pactree -d 1 bitwarden-electron42
pactree -d 1 mailspring-electron42-git
awk 'index($0, "exec electron42") { found=1 } END { exit !found }' /usr/bin/bitwarden-desktop
awk 'index($0, "exec electron42") { found=1 } END { exit !found }' /usr/bin/mailspring
```

Expected: both custom packages depend directly on Electron 42; Electron 39 and 41 remain installed but unused.

- [ ] **Step 6: Prepare isolated profiles and debugging flags**

Create two exact temporary directories:

```bash
bitwarden_profile=/tmp/bitwarden-electron42-smoke-profile
mailspring_config=/tmp/mailspring-electron42-smoke-config
test ! -e "$bitwarden_profile"
test ! -e "$mailspring_config"
install -d -m 700 "$bitwarden_profile" "$mailspring_config"
printf '%s\n' '--remote-debugging-address=127.0.0.1' '--remote-debugging-port=9224' \
  > "$mailspring_config/electron42-flags.conf"
```

Do not copy any file from the live application profiles.

- [ ] **Step 7: Start Bitwarden with its isolated profile**

Use the process supervisor rather than a background shell:

```text
hub start
  name: bitwarden-electron42-smoke
  application: /usr/bin/bitwarden-desktop
  args:
    - --user-data-dir=/tmp/bitwarden-electron42-smoke-profile
    - --remote-debugging-address=127.0.0.1
    - --remote-debugging-port=9223
  ready.log: DevTools listening
  ready.port: 9223
  ready.timeout: 30
```

Query `http://127.0.0.1:9223/json/list`. Expected: at least one target with `type: "page"`, a nonempty title or URL, and a `webSocketDebuggerUrl`. Do not sign in.

Inspect supervisor logs and reject preload, process-isolation, native-module, renderer-crash, or sandbox errors.

- [ ] **Step 8: Start Mailspring with its isolated configuration**

Use:

```text
hub start
  name: mailspring-electron42-smoke
  application: /usr/bin/mailspring
  env:
    XDG_CONFIG_HOME: /tmp/mailspring-electron42-smoke-config
  ready.log: DevTools listening
  ready.port: 9224
  ready.timeout: 30
```

Query `http://127.0.0.1:9224/json/list`. Expected: at least one page target and no account configured. Inspect logs and reject `NODE_MODULE_VERSION`, `ERR_DLOPEN_FAILED`, database, renderer-crash, or sandbox failures.

- [ ] **Step 9: Stop smoke processes and clean temporary profiles**

Stop both supervised processes through `hub stop`. Then run:

```bash
test "$bitwarden_profile" = /tmp/bitwarden-electron42-smoke-profile
test "$mailspring_config" = /tmp/mailspring-electron42-smoke-config
rm -rf -- "$bitwarden_profile" "$mailspring_config"
```

Expected: both guards pass and only the temporary directories are removed.

### Task 5: Remove superseded Electron runtimes and verify final state

**Files:**
- Remove package: `electron39`
- Remove package: `electron41-bin`
- Modify: `README.md`

**Interfaces:**
- Consumes: installed custom packages that passed isolated renderer tests.
- Produces: one shared Electron 42 runtime, final package integrity evidence, and documented SAUR packages.

- [ ] **Step 1: Prove no installed package still needs Electron 39 or 41**

Run:

```bash
pactree -r -d 1 electron39
pactree -r -d 1 electron41-bin
pacman -Rs --print --print-format '%n' electron39 electron41-bin
```

Expected reverse trees contain only the runtime roots, and the dry-run prints exactly:

```text
electron41-bin
electron39
```

Abort if any application or additional dependency appears.

- [ ] **Step 2: Remove the two superseded runtimes**

```bash
ssh sveinbjorn pacman -Rns electron39 electron41-bin
```

Expected: only those two packages are removed.

- [ ] **Step 3: Repeat cold native-module and isolated startup checks**

First verify the installed Electron ABI and native modules:

```bash
ELECTRON_RUN_AS_NODE=1 /usr/lib/electron42/electron \
  -p 'JSON.stringify({electron:process.versions.electron,node:process.versions.node,modules:process.versions.modules,napi:process.versions.napi})'
bitwarden_node=/usr/lib/bitwarden/app.asar.unpacked/node_modules/@bitwarden/desktop-napi/desktop_napi.node
mailspring_node=/usr/lib/mailspring/app.asar.unpacked/node_modules/@libsql/linux-x64-gnu/index.node
ELECTRON_RUN_AS_NODE=1 /usr/lib/electron42/electron \
  -e "require(${bitwarden_node@Q}); console.log('bitwarden desktop_napi loaded')"
ELECTRON_RUN_AS_NODE=1 /usr/lib/electron42/electron \
  -e "require(${mailspring_node@Q}); console.log('mailspring @libsql/linux-x64-gnu loaded')"
```

Expected: Electron reports module ABI 146, both modules print their loaded messages, and neither command reports `ERR_DLOPEN_FAILED`.

Create fresh isolated profiles:

```bash
bitwarden_profile=/tmp/bitwarden-electron42-final-profile
mailspring_config=/tmp/mailspring-electron42-final-config
test ! -e "$bitwarden_profile"
test ! -e "$mailspring_config"
install -d -m 700 "$bitwarden_profile" "$mailspring_config"
printf '%s\n' '--remote-debugging-address=127.0.0.1' '--remote-debugging-port=9224' \
  > "$mailspring_config/electron42-flags.conf"
```

Start Bitwarden with the process supervisor:

```text
hub start
  name: bitwarden-electron42-final
  application: /usr/bin/bitwarden-desktop
  args:
    - --user-data-dir=/tmp/bitwarden-electron42-final-profile
    - --remote-debugging-address=127.0.0.1
    - --remote-debugging-port=9223
  ready.log: DevTools listening
  ready.port: 9223
  ready.timeout: 30
```

Start Mailspring with:

```text
hub start
  name: mailspring-electron42-final
  application: /usr/bin/mailspring
  env:
    XDG_CONFIG_HOME: /tmp/mailspring-electron42-final-config
  ready.log: DevTools listening
  ready.port: 9224
  ready.timeout: 30
```

Query `http://127.0.0.1:9223/json/list` and `http://127.0.0.1:9224/json/list`. Each must return at least one page target with a `webSocketDebuggerUrl`. Inspect both supervisor logs and reject preload, process-isolation, `NODE_MODULE_VERSION`, database, renderer-crash, or sandbox errors.

Stop both processes through `hub stop`, then remove only the guarded temporary profiles:

```bash
test "$bitwarden_profile" = /tmp/bitwarden-electron42-final-profile
test "$mailspring_config" = /tmp/mailspring-electron42-final-config
rm -rf -- "$bitwarden_profile" "$mailspring_config"
```

Expected: both native modules load and both renderer endpoints become ready after Electron 39 and Electron 41 are absent.

- [ ] **Step 4: Compare package-database integrity before and after**

Run:

```bash
pacman -Dk > /tmp/pacman-Dk.after-electron42.txt 2>&1 || true
diff -u /tmp/pacman-Dk.before-electron42.txt /tmp/pacman-Dk.after-electron42.txt
```

Expected: no new missing dependency or ownership conflict attributable to the custom packages. Pre-existing defects must be reported separately rather than called fixed.

- [ ] **Step 5: Verify final runtime and disk state**

Run:

```bash
pacman -Q bitwarden-electron42 mailspring-electron42-git electron42
pacman -Q electron39 electron41-bin
pactree -r -d 1 electron42
pacman -Qk bitwarden-electron42 mailspring-electron42-git electron42
```

Expected:

- the first command succeeds;
- the second reports both old runtimes absent;
- Electron 42 has both custom applications as reverse dependencies;
- all three installed packages pass file checks.

Record `du` or package installed-size evidence without claiming ZFS snapshots released equivalent physical space.

- [ ] **Step 6: Add both packages to the repository README**

Add rows under `## Packages`:

```markdown
| [`bitwarden-electron42`](bitwarden-electron42/) | Bitwarden Desktop rebuilt for the shared system Electron 42 runtime | Maintained local replacement for repository `bitwarden` |
| [`mailspring-electron42-git`](mailspring-electron42-git/) | Mailspring Git rebuilt for Electron 42 with ABI-matched native modules | Maintained local replacement for AUR `mailspring-git` |
```

Add build examples that build each directory independently and state that native-module and isolated-profile gates must pass before replacing installed packages.

- [ ] **Step 7: Run final repository checks**

Run from the SAUR root:

```bash
git diff --check
(
  set -e
  cd bitwarden-electron42
  bash -n PKGBUILD
  bash -n bitwarden.sh
  cmp -s .SRCINFO <(makepkg --printsrcinfo)
)
(
  set -e
  cd mailspring-electron42-git
  bash -n PKGBUILD
  bash -n mailspring.sh
  cmp -s .SRCINFO <(makepkg --printsrcinfo)
)
```

Expected: every command exits 0. Each subshell exits nonzero if any check
inside it fails, including a stale `.SRCINFO`; `cmp` is the last command
so its status is the subshell's status.

- [ ] **Step 8: Commit final repository documentation**

```bash
git add README.md
git commit -m "docs: document Electron 42 application packages"
```

- [ ] **Step 9: Report completion with evidence**

Report separately:

- package archives built and their versions;
- native ABI and renderer smoke-test results;
- installed package transition;
- removal of Electron 39/41;
- `pacman -Dk` before/after delta;
- logical installed-size change versus physical ZFS reclamation;
- any build, namcap, application, or pre-existing package-database issue that remains.
