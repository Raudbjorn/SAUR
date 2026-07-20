# SAUR and `headroom-git` Publication Design

**Date:** 2026-07-20
**Status:** Approved

## Goal

Publish the entire `SAUR` workspace as a public GitHub repository, replace copied ArchWiki snapshots with a concise packaging handbook, and add a full-featured, Arch-native VCS package for Headroom.

## Repository boundary

The repository root is `SAUR/`, with `main` as its default branch. It will be published as `Raudbjorn/SAUR` with public visibility.

The local checkout at `headroom-git/headroom/` is disposable upstream source used for research. It is not package source material and must not be tracked. The root `.gitignore` will contain the explicitly requested `*/.git` rule, an explicit `headroom-git/headroom/` rule that actually prevents nested-repository gitlinks, and standard makepkg output rules.

## Documentation

The root `README.md` will explain:

- the repository's purpose and non-official status;
- its directory layout and current package inventory;
- how to review, build, install, and update VCS packages;
- the validation and contribution expectations;
- where to find the concise packaging handbook.

The copied ArchWiki markdown snapshots under `docs/` will be removed. Their durable, task-relevant guidance will be replaced by one original `docs/packaging-guide.md`, with links to authoritative ArchWiki and manual pages. `docs/template.PKGBUILD` remains as a reusable local template.

`headroom-git/README.md` will document package-specific scope, full-feature dependencies, AUR-helper requirements, build/install/update commands, validation commands, and the distinction between this package repository and upstream Headroom.

## Package design

`headroom-git/PKGBUILD` will:

- use `git+https` against the canonical Headroom repository;
- derive VCS versions from upstream tags and Git revisions in `pkgver()`;
- build the mixed Python/Rust distribution with Maturin and Cargo;
- use a source-local Cargo home and locked dependency resolution;
- install the wheel with `python-installer` without downloading dependencies during packaging;
- install upstream `LICENSE` and `NOTICE` files;
- provide and conflict with the stable `headroom` package name;
- declare the complete upstream `[all]` feature dependency set using Arch repository or AUR package names.

The package remains Arch-native: dependencies are owned by pacman, not hidden in a bundled `uv` or virtualenv installation. Because several full-feature dependencies are AUR packages, users must install them with an AUR helper or build them before invoking plain `makepkg`.

## Error handling and safety

Packaging commands fail immediately on missing tools, source errors, lockfile failures, wheel build failures, or installation failures. No verification failure is suppressed.

The publication workflow stages files explicitly, reviews the complete tracked file list, excludes the nested upstream checkout and build artifacts, creates the GitHub repository only after local validation, pushes without rewriting history, and verifies remote visibility and the default branch.

## Verification

The completed work must pass:

1. `bash -n headroom-git/PKGBUILD`;
2. `makepkg --printsrcinfo` with a clean `.SRCINFO` regeneration;
3. source retrieval and VCS version resolution;
4. `namcap` against the recipe and built package;
5. an actual source build with `makepkg --nodeps` when runtime dependencies are not locally installed;
6. package-content inspection for the CLI, Python module, Rust extension, license, and notice;
7. an isolated smoke test of the packaged `headroom` command where the local dependency set permits it;
8. Git tracked-file and ignored-file audits;
9. GitHub API verification that `Raudbjorn/SAUR` is public and uses `main`.

## Non-goals

- Publishing to the AUR itself.
- Maintaining copies of ArchWiki articles.
- Bundling Python dependencies in a private environment.
- Tracking or modifying the upstream Headroom checkout.
- Creating companion PKGBUILDs for missing dependencies.
