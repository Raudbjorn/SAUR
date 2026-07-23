# Electron 42 Application Unification Design

**Date:** 2026-07-23  
**Repository:** SAUR  
**Status:** Approved for implementation planning

## Objective

Replace the separate Electron 39 and Electron 41 runtimes used by Bitwarden and Mailspring with one maintained Electron 42 runtime, without falsifying package dependencies or exposing the live Bitwarden and Mailspring profiles to an unsupported runtime during validation.

The resulting packages remain independently maintainable in SAUR and preserve the applications' existing executable names, desktop entries, and profile locations.

## Current state and evidence

- `bitwarden` 2026.3.1-2.1 depends on `electron39` and launches `/usr/lib/bitwarden/app.asar` through `electron39`.
- `mailspring-git` 1.21.1 depends on the `electron41` provider supplied by `electron41-bin` and launches `/usr/lib/mailspring/app.asar` through `electron41`.
- Cached Electron 42.7.1 uses Node 24.18.0, N-API 10, and `NODE_MODULE_VERSION` 146.
- Electron 39 uses `NODE_MODULE_VERSION` 140. Bitwarden's Rust `desktop_napi.node` loads successfully under Electron 42 because it uses the stable N-API boundary.
- Electron 41 uses `NODE_MODULE_VERSION` 145. Mailspring's installed `better_sqlite3.node` fails under Electron 42 with `ERR_DLOPEN_FAILED` because Electron 42 requires module version 146. Mailspring must therefore be rebuilt; changing only its launcher or dependency metadata is invalid.
- The current Mailspring AUR recipe tracks upstream 1.23.x and builds against Electron 41. The custom recipe will update the installed 1.21.1 package to the current upstream revision while changing the Electron target to 42.
- Electron 42 and `openai-codex-desktop` were removed in a package transaction on 2026-07-23 at 11:51 UTC. Electron 42 must be reinstalled as part of the transition.

## Package architecture

### `bitwarden-electron42`

`bitwarden-electron42` will derive from the current Arch `bitwarden` PKGBUILD and package the same upstream desktop release.

The package will:

- depend on `electron42` rather than `electron39`;
- provide `bitwarden` at the packaged upstream version;
- conflict with the official `bitwarden` package;
- retain `/usr/bin/bitwarden-desktop`, `/usr/share/applications/bitwarden.desktop`, and `/usr/lib/bitwarden`;
- build Electron output against `/usr/lib/electron42` and the installed Electron 42 version;
- retain the existing process-isolation preload library and native-messaging patches;
- launch the application through `electron42`.

The package name prevents a later repository upgrade from silently replacing the custom Electron target with the official Electron 39 package. Updating Bitwarden becomes an explicit SAUR recipe maintenance operation.

### `mailspring-electron42-git`

`mailspring-electron42-git` will derive from the current `mailspring-git` AUR recipe and follow the latest upstream Git revision.

The package will:

- set the Electron build target to major version 42;
- depend on `electron42` rather than an Electron 41 provider;
- provide `mailspring` at the derived upstream version;
- conflict with both `mailspring` and `mailspring-git`;
- retain `/usr/bin/mailspring`, `/usr/share/applications/mailspring.desktop`, and `/usr/lib/mailspring`;
- preserve the existing system-Electron build path;
- rebuild `better-sqlite3` and all other native modules for Electron ABI 146;
- read `electron42-flags.conf` instead of `electron41-flags.conf` in the launcher.
- remove the upstream recipe's `curl -s ipinfo.io/country` geolocation branch and select the standard npm/Electron registries deterministically, so clean builds have no undeclared or unbounded location probe.

The recipe must not copy the currently installed Electron-41 native objects into the new package.

## Repository layout

The implementation will add the following package directories:

```text
bitwarden-electron42/
├── PKGBUILD
├── .SRCINFO
├── README.md
├── bitwarden.sh
├── bitwarden.desktop
└── patches required by the Arch recipe

mailspring-electron42-git/
├── PKGBUILD
├── .SRCINFO
├── README.md
└── mailspring.sh
```

Only reproducible package inputs belong in Git. Build directories, source checkouts, package archives, logs, and credentials remain ignored.

## Build and validation sequence

Both custom packages must build successfully before the installed applications are changed.

For each recipe:

1. Review every source, patch, lifecycle function, and network operation.
2. Run `bash -n PKGBUILD`.
3. Verify fixed-source checksums where applicable and inspect VCS source ownership.
4. Generate `.SRCINFO` with `makepkg --printsrcinfo`; never edit it manually.
5. Run `namcap PKGBUILD`.
6. Perform a clean local build.
7. Run `namcap` against the resulting package.
8. Inspect the package archive for expected launchers, application archives, native modules, metadata, and dependencies.
9. Run a clean-chroot build when the dependency graph permits it.

Native-module verification is mandatory:

- load Bitwarden's packaged `desktop_napi.node` with Electron 42 in Node mode;
- load Mailspring's packaged `better_sqlite3.node` with Electron 42 in Node mode;
- require successful exit and reject any `NODE_MODULE_VERSION`, `ERR_DLOPEN_FAILED`, missing-symbol, or missing-library error.

## Installation transition

The installation transition begins only after both package archives pass their pre-install validation.

1. Ensure no `pacman`, `paru`, or application process is active.
2. Confirm rollback sources remain available for official Bitwarden, Electron 39, and the AUR Mailspring/Electron 41 path.
3. Install Electron 42 and both custom packages in one controlled package operation, accepting replacement of the original application packages.
4. Keep Electron 39 and Electron 41 installed during initial smoke testing.
5. Verify the installed launchers invoke Electron 42 and that `pactree` resolves both custom packages to `electron42`.
6. Run isolated smoke tests.
7. Remove Electron 39 and Electron 41 only after both applications pass.
8. Run `pacman -Dk` and distinguish pre-existing package-database defects from any defects introduced by the transition.

## Isolated smoke tests

Tests must not open the production credential or mail profiles.

### Bitwarden

- Set a temporary profile with `--user-data-dir`.
- Do not sign in or import credentials.
- Start the packaged application under Electron 42.
- Confirm the process remains alive long enough to render its initial window.
- Check stderr and journal output for preload, native-module, sandbox, renderer, and process-isolation failures.
- Close the isolated process and remove the temporary profile.

### Mailspring

- Set a temporary `XDG_CONFIG_HOME` and any other profile variables used by the launcher.
- Do not connect a mail account.
- Start the packaged application under Electron 42.
- Confirm the process remains alive long enough to render its initial setup window.
- Verify `better-sqlite3` loads without ABI errors and that startup does not modify the production Mailspring profile.
- Close the isolated process and remove the temporary profile.

A successful process start without native-module errors is necessary but not sufficient. Both applications must render their initial window and exit cleanly before Electron 39 or 41 is removed.

## Failure handling and rollback

If either build or isolated smoke test fails:

- do not remove Electron 39 or Electron 41;
- keep the original application packages installed when failure occurs before transition;
- if failure occurs after replacement, reinstall repository `bitwarden` and AUR `mailspring-git`, allowing their supported Electron dependencies to return;
- preserve build logs and the exact native-module error for diagnosis;
- do not test the failed package against a live application profile.

If the custom packages pass but a later upstream update stops building or running on Electron 42, hold the last working custom package version while evaluating the upstream Electron target. Do not satisfy an Electron 39 or 41 dependency with a fake provider package.

## Maintenance policy

For each upstream update:

1. Refresh the upstream version or Git revision.
2. Review Electron requirements and native dependency changes.
3. Rebuild all native modules against the installed Electron 42 release.
4. Repeat package validation and isolated smoke tests.
5. Regenerate `.SRCINFO`.
6. Commit the recipe, patches, launcher, README, and `.SRCINFO` together.

If upstream requires an API unavailable in Electron 42 or moves to a newer supported major, correctness takes precedence over runtime consolidation. The package should move to the required Electron major rather than carrying broad compatibility patches or false dependency metadata.

## Acceptance criteria

The migration is complete when:

- both custom packages are reproducibly represented in SAUR;
- both package archives pass syntax, metadata, source, native-module, and package-content checks;
- Bitwarden and Mailspring render from isolated profiles under Electron 42;
- both installed launchers invoke Electron 42;
- neither installed custom package depends on or invokes Electron 39 or Electron 41;
- Electron 39 and Electron 41 can be removed without dependency breakage;
- live Bitwarden and Mailspring profile paths were not used during testing;
- rollback commands and maintenance instructions are documented in each package README;
- no new `pacman -Dk` errors are introduced.
