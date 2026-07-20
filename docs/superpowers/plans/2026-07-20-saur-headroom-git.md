# SAUR and `headroom-git` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a clean public SAUR repository with consolidated packaging documentation and a validated full-feature `headroom-git` Arch package.

**Architecture:** The repository root owns documentation and package recipes, while disposable upstream checkouts remain ignored. `headroom-git` builds upstream's Python/Rust wheel from Git with system-owned dependencies and publishes Arch metadata through `PKGBUILD` plus `.SRCINFO`.

**Tech Stack:** Bash/PKGBUILD, makepkg, Maturin, Cargo, Python installer, namcap, Git, GitHub CLI.

## Global Constraints

- Publish the entire `SAUR/` root as public `Raudbjorn/SAUR` on `main`.
- Replace copied ArchWiki snapshots with one original `docs/packaging-guide.md`; retain `docs/template.PKGBUILD`.
- Install the full upstream `[all]` dependency set through pacman/AUR packages, never a bundled virtual environment.
- `headroom-git` provides `headroom-ai`, conflicts with `headroom-ai` and unrelated `headroom`, and never provides `headroom`.
- Preserve the requested `*/.git` ignore rule and explicitly ignore disposable upstream checkout paths.
- Stage explicit paths only; never bypass Git hooks or rewrite remote history.

---

### Task 1: Repository documentation and boundaries

**Files:**
- Modify: `README.md`
- Create: `.gitignore`
- Create: `docs/packaging-guide.md`
- Delete: copied `docs/*.md` snapshots except the new handbook and internal design/plan documents
- Retain: `docs/template.PKGBUILD`

**Interfaces:**
- Consumes: approved repository and documentation design.
- Produces: public repository navigation, build policy, and ignored-source boundaries.

- [ ] **Step 1:** Write `.gitignore` with `*/.git`, explicit `headroom-git/headroom/` and `tinbase-git/tinbase/` checkout exclusions, makepkg `src/`/`pkg/` trees, package archives, logs, and generated Python caches.
- [ ] **Step 2:** Rewrite `README.md` with repository status, structure, package table, build/install/update commands, verification requirements, and links to the handbook and package README.
- [ ] **Step 3:** Write `docs/packaging-guide.md` covering package review, VCS versioning, source/build/package phases, dependency classification, `.SRCINFO`, clean builds, namcap, reproducibility, and authoritative Arch references.
- [ ] **Step 4:** Remove only the copied ArchWiki markdown snapshots; preserve the template and internal approved planning artifacts.
- [ ] **Step 5:** Verify links and ignored paths with `git check-ignore -v headroom-git/headroom tinbase-git/tinbase` and review `git status --short --ignored`.

### Task 2: Full-feature Headroom VCS package

**Files:**
- Create: `headroom-git/PKGBUILD`
- Create: `headroom-git/README.md`
- Generate: `headroom-git/.SRCINFO`

**Interfaces:**
- Consumes: canonical upstream Git source and dependency mapping from `pyproject.toml` `[all]`.
- Produces: installable `headroom-git` package and AUR-compatible metadata.

- [ ] **Step 1:** Verify canonical source, latest tags, current project version, license, wheel layout, and upstream dependency markers.
- [ ] **Step 2:** Write a VCS recipe with `pkgver()`, source-local Cargo state, locked Maturin build, wheel installation, license/notice installation, full official/AUR dependencies, `provides=('headroom-ai')`, and `conflicts=('headroom-ai' 'headroom')`.
- [ ] **Step 3:** Write `headroom-git/README.md` with identity-collision warning, feature scope, AUR dependency bootstrap, build/install/update instructions, and validation commands.
- [ ] **Step 4:** Run `bash -n PKGBUILD`, `makepkg --printsrcinfo > .SRCINFO`, then compare regenerated output byte-for-byte.
- [ ] **Step 5:** Run `makepkg --nodeps --cleanbuild --clean --force`; fail on any source, Cargo, Maturin, or wheel error.
- [ ] **Step 6:** Run namcap on both recipe and package, inspect archive paths, and smoke-test the extracted CLI when dependencies permit.

### Task 3: Review, commit, and public publication

**Files:**
- Review all tracked repository files.

**Interfaces:**
- Consumes: verified docs, package recipe, metadata, and build evidence.
- Produces: public `Raudbjorn/SAUR` repository on `main`.

- [ ] **Step 1:** Run focused content checks for placeholders, stale copied-wiki markup, nested Git checkout leakage, and generated build artifacts.
- [ ] **Step 2:** Stage only `.gitignore`, `README.md`, retained docs, `headroom-git/PKGBUILD`, `headroom-git/.SRCINFO`, and `headroom-git/README.md`; review `git diff --cached --stat` and `git diff --cached`.
- [ ] **Step 3:** Commit the implementation with hooks enabled.
- [ ] **Step 4:** Create `Raudbjorn/SAUR` as a public GitHub repository using the existing local repository, add `origin`, and push `main` without force.
- [ ] **Step 5:** Verify through GitHub that visibility is `PUBLIC`, default branch is `main`, the remote head matches local HEAD, and ignored source/build paths are absent.
