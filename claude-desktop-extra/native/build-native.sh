#!/usr/bin/env bash
# Local bleeding-edge, host-tuned build of claude-desktop-extra.
#
# 1. Syncs the upstream repo (gh/) and the four Computer Use bridge repos to
#    their remote HEADs (survives upstream history rewrites without losing work).
#    Missing checkouts are cloned on the first run.
# 2. Builds the bridges with host-tuned flags against the NEWEST semver-compatible
#    crates (cargo update), falling back to the committed Cargo.lock on failure.
# 3. Runs upstream's build-local.sh against the newest official apt .deb, with
#    local-patches/*.patch applied to a staged copy, and drops the package into
#    $PKG_OUT.
#
# Usage: ./build-native.sh [build-local.sh args...]   (e.g. --pkgrel 7)
# Env:   CDE_SRC  work dir for checkouts, toolchain and logs
#                 (default ${XDG_CACHE_HOME:-~/.cache}/claude-desktop-extra-native)
#        PKG_OUT  where the finished package is copied (default $CDE_SRC/pkgdest)
#        AUR_DIR  dir holding the recipe whose pkgrel is bumped (default: ..)
#        CARGO_LOCKED=1, BRIDGE_PARALLEL=0 (serial bridges),
#        BRIDGES_ONLY=1 (stop after bridges), CRATE_HOLDS_OFF=1
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SELF")"
# Exported so the re-entered bridge workers resolve the same work dir.
export CDE_SRC="${CDE_SRC:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-desktop-extra-native}"
ROOT="$CDE_SRC"
mkdir -p "$ROOT"
CU="$ROOT/computer-use"
PKG_OUT="${PKG_OUT:-$ROOT/pkgdest}"
AUR_DIR="${AUR_DIR:-$(dirname "$SCRIPT_DIR")}"
LOCAL_PATCHES="$SCRIPT_DIR/local-patches"
GH_URL="https://github.com/patrickjaja/claude-desktop-extra.git"
# dir → upstream (the gnome bridge's repository is named gnome-bridge).
declare -A BRIDGE_URLS=(
    [x11-bridge]="https://github.com/patrickjaja/x11-bridge.git"
    [wlroots-bridge]="https://github.com/patrickjaja/wlroots-bridge.git"
    [kwin-portal-bridge]="https://github.com/patrickjaja/kwin-portal-bridge.git"
    [gnome-portal-bridge]="https://github.com/patrickjaja/gnome-bridge.git"
)
APT_PACKAGES_URL="https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages"
CU_ATSPI_URL="https://github.com/patrickjaja/cu-atspi"
NET_TIMEOUT_S=60
# Non-fatal issues, printed at the end. A file, because bridge builds run in
# separate worker processes where array appends would be lost.
NOTES="$ROOT/.build-notes"
BRIDGE_OUT="$ROOT/.bridge-out"

log()  { printf '\033[0;36m[native]\033[0m %s\n' "$*" >&2; }
note() { printf '%s\n' "$*" >>"$NOTES"; log "NOTE: $*"; }

# Per-stage wall-clock, printed at the end (observability for tuning).
TIMINGS="$ROOT/.build-timings"
stage_t0=""; stage_name=""
stage() { # <name> — closes the previous stage, opens the next
    local now="${EPOCHREALTIME/,/.}"
    [[ -n "$stage_name" ]] && awk -v a="$stage_t0" -v b="$now" -v n="$stage_name" \
        'BEGIN { printf "%-22s %6.1fs\n", n, b - a }' >>"$TIMINGS"
    stage_name="$1"; stage_t0="$now"
}

# ── Bridge worker (re-entered by the generated bridge Makefile) ───────────────
# One process per bridge, all sharing make's jobserver: cargo is a jobserver
# client, so the four builds overlap (fat-LTO/cgu=1 links are single-threaded
# and otherwise leave most job slots idle) while the TOTAL stays at -jN.
# Writes the binary path to $BRIDGE_OUT/<dir>; output goes to $BRIDGE_OUT/<dir>.log.
build_bridge_worker() { # <dir> <bin> [target]
    local dir="$1" bin="$2" target="${3:-}" src="$CU/$1"
    local tgt=(${target:+--target "$target"}) extra=()
    [[ -n "${CU_ATSPI_PATCH:-}" ]] &&
        extra=(--config "patch.\"$CU_ATSPI_URL\".cu-atspi.path=\"$CU_ATSPI_PATCH\"")
    if [[ "${CARGO_LOCKED:-0}" != 1 ]] &&
        (cd "$src" && cargo build --release "${tgt[@]}" "${extra[@]}"); then
        :
    else
        [[ "${CARGO_LOCKED:-0}" != 1 ]] &&
            note "$dir: build with updated crates failed; retrying with committed Cargo.lock"
        git -C "$src" checkout -q -- Cargo.lock
        (cd "$src" && cargo build --release --locked "${tgt[@]}" "${extra[@]}")
    fi
    # Leave the bridge checkout clean so the next sync fast-forwards.
    git -C "$src" checkout -q -- Cargo.lock
    local out="$src/target/${target:+$target/}release/$bin"
    [[ -x "$out" ]] || { echo "missing $out" >&2; return 1; }
    echo "$out" >"$BRIDGE_OUT/$dir"
}
if [[ "${1:-}" == __bridge ]]; then
    shift
    exec >"$BRIDGE_OUT/$1.log" 2>&1
    build_bridge_worker "$@"
    exit
fi

: >"$NOTES"; : >"$TIMINGS"

# ── First-run bootstrap ───────────────────────────────────────────────────────
clone_if_missing() { # <url> <dir>
    [[ -d "$2/.git" ]] && return 0
    log "cloning $1 → $2"
    timeout 600 git clone -q "$1" "$2"
}
clone_if_missing "$GH_URL" "$ROOT/gh"
for dir in "${!BRIDGE_URLS[@]}"; do
    clone_if_missing "${BRIDGE_URLS[$dir]}" "$CU/$dir"
done

stage "toolchain"

# ── Parallelism ───────────────────────────────────────────────────────────────
# A MAKEFLAGS -jN in the environment is treated as a deliberate throttle; honour it rather
# than blindly using every core. Fall back to nproc only when unset.
JOBS="$(sed -nE 's/.*-j[[:space:]]*([0-9]+).*/\1/p' <<<"${MAKEFLAGS:-}")"
JOBS="${JOBS:-$(nproc)}"
export CARGO_BUILD_JOBS="$JOBS"
log "jobs=$JOBS (from ${MAKEFLAGS:+MAKEFLAGS}${MAKEFLAGS:-nproc})"

# ── Repo sync ─────────────────────────────────────────────────────────────────
# Fast-forward to upstream. If upstream rewrote history (happened to
# wlroots-bridge 2026-11), reset ONLY when the local HEAD tree also exists in
# upstream history (nothing local would be lost); keep a backup branch anyway.
sync_repo() { # <dir>
    local d="$1" tree
    timeout "$NET_TIMEOUT_S" git -C "$d" fetch -q
    git -C "$d" merge -q --ff-only '@{u}' 2>/dev/null && return 0
    if [[ -n "$(git -C "$d" status --porcelain --untracked-files=no)" ]]; then
        echo "sync_repo: $d has local modifications and diverged from upstream" >&2
        return 1
    fi
    tree="$(git -C "$d" rev-parse 'HEAD^{tree}')"
    if ! git -C "$d" log --format=%T '@{u}' | grep -qx "$tree"; then
        echo "sync_repo: $d diverged with local-only content; resolve manually" >&2
        return 1
    fi
    git -C "$d" branch -f "backup/pre-reset-$(date +%F)" HEAD
    git -C "$d" reset -q --hard '@{u}'
    note "$(basename "$d"): upstream rewrote history; reset to $(git -C "$d" rev-parse --short HEAD) (backup branch kept)"
}

# ── Rust toolchain ────────────────────────────────────────────────────────────
# Isolated rustup (stable + musl std). System rust and rust-musl drift apart in
# pkgrel (E0514) and are pinned in pacman.conf IgnorePkg; keep the fix local.
TOOLCHAIN="$ROOT/.toolchain"
if [[ -x "$TOOLCHAIN/cargo/bin/cargo" ]]; then
    export RUSTUP_HOME="$TOOLCHAIN/rustup" CARGO_HOME="$TOOLCHAIN/cargo"
    export PATH="$CARGO_HOME/bin:$PATH"
    if ! timeout 600 rustup update stable --no-self-update >/dev/null 2>&1; then
        note "rustup update stable failed; building with $(rustc -V)"
    fi
fi
log "toolchain: $(rustc -V)"

# Respect deliberate env; only fill in what's missing.
: "${RUSTC_WRAPPER:=$(command -v sccache || true)}"
export RUSTC_WRAPPER
[[ -n "$RUSTC_WRAPPER" ]] && export CARGO_INCREMENTAL=0
if [[ -z "${RUSTFLAGS:-}" ]]; then
    RUSTFLAGS="-C target-cpu=native"
    command -v mold >/dev/null && RUSTFLAGS+=" -C link-arg=-fuse-ld=mold"
fi
export RUSTFLAGS
# Local-only binaries: trade build time for runtime.
export CARGO_PROFILE_RELEASE_LTO=fat CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1

# cu-atspi is pinned by git rev in three bridges. If upstream main moved past
# the pin, build against main via a [patch] to a local clone (no manifest edits).
# Passed to the bridge workers through the environment.
export CU_ATSPI_URL CU_ATSPI_PATCH=""
atspi_pin="$(grep -ohP 'cu-atspi = \{ git = "[^"]+", rev = "\K[0-9a-f]+' "$CU"/*/Cargo.toml | sort -u | head -1 || true)"
atspi_head="$(timeout "$NET_TIMEOUT_S" git ls-remote "$CU_ATSPI_URL" refs/heads/main | cut -f1 || true)"
if [[ -n "$atspi_pin" && -n "$atspi_head" && "$atspi_pin" != "$atspi_head" ]]; then
    [[ -d "$CU/cu-atspi" ]] || git clone -q "$CU_ATSPI_URL" "$CU/cu-atspi"
    sync_repo "$CU/cu-atspi"
    CU_ATSPI_PATCH="$CU/cu-atspi"
    note "cu-atspi pinned at ${atspi_pin:0:9}, building against main ${atspi_head:0:9}"
elif [[ -z "$atspi_head" ]]; then
    note "could not query cu-atspi upstream; using pinned rev"
fi
atspi_extra=()
[[ -n "$CU_ATSPI_PATCH" ]] &&
    atspi_extra=(--config "patch.\"$CU_ATSPI_URL\".cu-atspi.path=\"$CU_ATSPI_PATCH\"")

# Crates whose newest semver-compatible release breaks a bridge. They stay at
# the bridge's committed Cargo.lock version while everything else floats to the
# newest release (cheaper than falling back to the whole committed lock).
# Re-test by running with CRATE_HOLDS_OFF=1.
#   winit-common: 0.31.0-beta.4 (and its =winit-core) made keyboard enums
#     non_exhaustive; iced_exdevtools 0.19.1 matches them exhaustively (E0004).
#   lamco-portal: 0.4.7 added StreamInfo.mapping_id; bridges build the struct
#     literally (E0063).
declare -A CRATE_HOLDS=(
    [kwin-portal-bridge]="winit-common lamco-portal"
    [gnome-portal-bridge]="lamco-portal"
)
[[ "${CRATE_HOLDS_OFF:-0}" == 1 ]] && CRATE_HOLDS=()

# hold_crates <dir> — re-pin held crates to the committed lock's version.
hold_crates() {
    local dir="$1" c v
    for c in ${CRATE_HOLDS[$dir]:-}; do
        v="$(git -C "$CU/$dir" show HEAD:Cargo.lock |
            awk -v n="$c" '!found && $0 == "name = \"" n "\"" { getline; gsub(/version = |"/, ""); print; found = 1 }')"
        # (no early `exit` in awk: git show would take SIGPIPE and pipefail aborts)
        [[ -n "$v" ]] || { note "$dir: hold $c not in committed lock (stale hold?)"; continue; }
        if (cd "$CU/$dir" && cargo update -q -p "$c" --precise "$v" "${atspi_extra[@]}"); then
            note "$dir: held $c at $v (newest breaks the build)"
        else
            note "$dir: could not hold $c at $v"
        fi
    done
}

# dir:bin:target
BRIDGES=(
    x11-bridge:x11-bridge:x86_64-unknown-linux-musl
    wlroots-bridge:wlroots-bridge:x86_64-unknown-linux-musl
    kwin-portal-bridge:kwin-portal-bridge:
    gnome-portal-bridge:gnome-portal-bridge:
)

# Network-bound prep stays serial: sync, bump crates, prefetch them so the
# parallel workers don't contend on cargo's package-cache lock.
stage "bridge sync+update"
for spec in "${BRIDGES[@]}"; do
    IFS=: read -r dir _ _ <<<"$spec"
    # Cargo.lock is ours to regenerate; an interrupted run may have left it dirty.
    git -C "$CU/$dir" checkout -q -- Cargo.lock
    sync_repo "$CU/$dir"
    if [[ "${CARGO_LOCKED:-0}" != 1 ]]; then
        if (cd "$CU/$dir" && cargo update -q "${atspi_extra[@]}"); then
            hold_crates "$dir"
            (cd "$CU/$dir" && cargo fetch -q "${atspi_extra[@]}") || note "$dir: cargo fetch failed"
        else
            note "$dir: cargo update failed; worker will fall back to Cargo.lock"
        fi
    fi
done

stage "bridge build"
rm -rf "$BRIDGE_OUT" && mkdir -p "$BRIDGE_OUT"
export BRIDGE_OUT CARGO_LOCKED="${CARGO_LOCKED:-0}"
if [[ "${BRIDGE_PARALLEL:-1}" == 1 ]]; then
    # cargo only joins make's jobserver when it isn't given its own -j.
    unset CARGO_BUILD_JOBS
    mk="$BRIDGE_OUT/bridges.mk" names=()
    for spec in "${BRIDGES[@]}"; do
        IFS=: read -r dir bin target <<<"$spec"
        names+=("$dir")
        printf '%s:\n\t+@%q __bridge %q %q %q\n' "$dir" "$SELF" "$dir" "$bin" "$target"
    done >"$mk"
    printf '.PHONY: all %s\nall: %s\n' "${names[*]}" "${names[*]}" >>"$mk"
    log "building ${#names[@]} bridges in parallel under a shared -j$JOBS jobserver"
    make_rc=0
    env -u MAKEFLAGS -u MFLAGS make -k -j"$JOBS" -f "$mk" all || make_rc=$?
    export CARGO_BUILD_JOBS="$JOBS"
else
    make_rc=0
    for spec in "${BRIDGES[@]}"; do
        IFS=: read -r dir bin target <<<"$spec"
        "$SELF" __bridge "$dir" "$bin" "$target" || make_rc=$?
    done
fi
for spec in "${BRIDGES[@]}"; do
    IFS=: read -r dir _ _ <<<"$spec"
    if [[ ! -s "$BRIDGE_OUT/$dir" ]]; then
        log "$dir FAILED — last 40 log lines:"
        tail -n 40 "$BRIDGE_OUT/$dir.log" >&2
    fi
done
(( make_rc == 0 )) || { log "bridge build failed (rc=$make_rc); logs in $BRIDGE_OUT"; exit 1; }

export X11_BRIDGE_BIN WLROOTS_BRIDGE_BIN KWIN_PORTAL_BRIDGE_BIN GNOME_PORTAL_BRIDGE_BIN
X11_BRIDGE_BIN="$(<"$BRIDGE_OUT/x11-bridge")"
WLROOTS_BRIDGE_BIN="$(<"$BRIDGE_OUT/wlroots-bridge")"
KWIN_PORTAL_BRIDGE_BIN="$(<"$BRIDGE_OUT/kwin-portal-bridge")"
GNOME_PORTAL_BRIDGE_BIN="$(<"$BRIDGE_OUT/gnome-portal-bridge")"
for b in "$X11_BRIDGE_BIN" "$WLROOTS_BRIDGE_BIN" "$KWIN_PORTAL_BRIDGE_BIN" "$GNOME_PORTAL_BRIDGE_BIN"; do
    log "bridge: $b ($(stat -c %s "$b") bytes)"
done
[[ "${BRIDGES_ONLY:-0}" == 1 ]] && { stage "end"; cat "$TIMINGS" >&2; exit 0; }

stage "package"
sync_repo "$ROOT/gh"

# ── pkgrel ────────────────────────────────────────────────────────────────────
# The AUR repack of the same pkgver carries pkgrel N; a local -1 would be
# "upgraded" away by `paru -Syu`. Default to AUR pkgrel + 1 when versions match.
args=("$@")
if [[ ! " ${args[*]} " =~ \ (--pkgrel|-r)\  ]]; then
    apt_ver="$(curl -fsS --max-time "$NET_TIMEOUT_S" "$APT_PACKAGES_URL" | sed -n 's/^Version: //p' | sort -V | tail -1 || true)"
    aur_ver="$(sed -n 's/^pkgver=//p' "$AUR_DIR/PKGBUILD" 2>/dev/null || true)"
    aur_rel="$(sed -n 's/^pkgrel=//p' "$AUR_DIR/PKGBUILD" 2>/dev/null || true)"
    rel=1
    [[ -n "$apt_ver" && "$apt_ver" == "$aur_ver" && "$aur_rel" =~ ^[0-9]+$ ]] && rel=$((aur_rel + 1))
    args+=(--pkgrel "$rel")
    log "apt=$apt_ver aur=$aur_ver-$aur_rel → pkgrel $rel"
fi

# ── Package ───────────────────────────────────────────────────────────────────
# Stage gh/ (minus .git/build/cache, ~260 MB) in tmpfs and build there:
#  * The ~3 GB of intermediates hit ENOSPC on the original host's near-full
#    mergerfs pool (every branch at its minfreespace cutoff).
#  * mergerfs clones dir attributes across branches, so `chmod g-s` did not stop
#    the setgid bit leaking into /usr/lib/claude-desktop dirs (2026-11-06).
#  * RAM-backed I/O is faster for the extract/patch/repack/compress churn.
# Falls back to building in place when /tmp is not a roomy tmpfs.
STAGE_TMPFS_MIN_KB=$((6 * 1024 * 1024))
GH="$ROOT/gh"
if [[ "$(stat -f -c %T /tmp)" == tmpfs ]] &&
    (( $(df --output=avail -k /tmp | tail -1) > STAGE_TMPFS_MIN_KB )); then
    STAGE="$(mktemp -d /tmp/cde-build.XXXXXX)"
    trap 'rm -rf "$STAGE"' EXIT
    rsync -a --chmod=Dg-s --exclude=/.git --exclude=/build --exclude=/cache "$ROOT/gh/" "$STAGE/gh/"
    GH="$STAGE/gh"
    # Local fixes for upstream build-script bugs: applied to the STAGED copy
    # only (gh/ checkout untouched, so sync_repo keeps fast-forwarding). A patch
    # that no longer applies is reported, not fatal — upstream may have fixed it.
    for lp in "$LOCAL_PATCHES"/*.patch; do
        [[ -e "$lp" ]] || continue
        if patch -d "$GH" -p1 --forward --silent --dry-run <"$lp" >/dev/null 2>&1; then
            patch -d "$GH" -p1 --forward --silent <"$lp"
            note "local patch applied: $(basename "$lp")"
        else
            note "local patch $(basename "$lp") no longer applies — upstream changed; re-check"
        fi
    done
    export BUILDDIR="$STAGE/makepkg"
    # Scratch for the absorbed-patch probe & co. (on the original host $TMPDIR
    # was a 99%-full zfs dataset; one unreproduced probe P2 failure on 2026-11-06).
    export TMPDIR="$STAGE/tmp"; mkdir -p "$TMPDIR"
    log "building in tmpfs stage $STAGE"
else
    export BUILDDIR="$ROOT/.makepkg-build"
    note "/tmp not a tmpfs with >6 GiB free; building in place on $(stat -f -c %T "$ROOT")"
    note "local patches NOT applied (in-place builds never modify the gh/ checkout)"
fi
rm -rf "$BUILDDIR" && mkdir -p "$BUILDDIR"
# (GNU chmod keeps setgid on dirs for numeric modes, so g-s explicitly.)
chmod g-s "$BUILDDIR" "$GH"
# ~/.makepkg.conf sets PKGDEST globally, so build-local.sh's `ls *.pkg.tar.zst`
# in build/ found nothing and exited 1 after a successful build. Point PKGDEST
# at build/ for this run (env beats makepkg.conf), then publish to $PKG_OUT.
export PKGDEST="$GH/build"
# Local artefact, byte-reproducibility irrelevant → parallel gzip.
export CLAUDE_ALLOW_PIGZ="${CLAUDE_ALLOW_PIGZ:-1}"
# compile-nim-patches.sh reads JOBS (else nproc); keep it inside the same budget.
export JOBS

"$GH/scripts/build-local.sh" "${args[@]}"

pkg="$(ls -t "$GH"/build/claude-desktop-extra-*.pkg.tar.zst | head -1)"

# Guard: never publish a package with setgid dirs or world-writable entries
# (the regression above shipped silently once). chrome-sandbox's 4755 is a file.
bad_modes="$(bsdtar -tvf "$pkg" | awk '($1 ~ /^d/ && $1 ~ /s/) || ($1 !~ /^l/ && substr($1, 9, 1) == "w")')"
if [[ -n "$bad_modes" ]]; then
    log "refusing to publish $pkg — bad modes:"; printf '%s\n' "$bad_modes" >&2
    exit 1
fi
mkdir -p "$PKG_OUT"
cp -f "$pkg" "$PKG_OUT/"
log "package: $PKG_OUT/$(basename "$pkg")"
echo "PKG=$PKG_OUT/$(basename "$pkg")"

stage "end"
log "stage timings:"; sed 's/^/  /' "$TIMINGS" >&2

if [[ -s "$NOTES" ]]; then
    log "issues encountered:"
    sed 's/^/  - /' "$NOTES" >&2
fi
