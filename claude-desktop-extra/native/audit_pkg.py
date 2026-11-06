#!/usr/bin/env python3
"""Pre-install security audit of a claude-desktop-extra package.

Reads the package archive and the upstream .deb as untrusted data (never
executes anything from them) and reports:
  * archive metadata: setuid/setgid, world-writable, non-root owners, device
    nodes, paths outside the expected prefixes, symlinks escaping the package
  * the .INSTALL scriptlet, diffed against the repo's copy, plus risky patterns
  * a file-by-file comparison against the official upstream .deb, so every
    byte that differs from Anthropic's signed release is accounted for
  * for re-packed asars: added/changed files and network hosts that appear
    only in the patched JavaScript
  * ELF hardening (PIE, RELRO, BIND_NOW, NX stack) of every non-upstream ELF
  * sha256 of the shipped bridges vs. the locally built binaries

Usage: python3 -I audit_pkg.py PKG DEB WORKDIR REPO_INSTALL [BRIDGE_BIN...]
Exit status: 0 = no blocking findings, 1 = blocking findings, 2 = usage/error.
"""

from __future__ import annotations

import difflib
import hashlib
import json
import logging
import posixpath
import re
import shutil
import stat
import subprocess
import sys
import tarfile
from dataclasses import dataclass, field
from pathlib import Path

log = logging.getLogger("audit")

ALLOWED_PREFIXES = ("usr/", ".PKGINFO", ".BUILDINFO", ".MTREE", ".INSTALL")
# chrome-sandbox must be setuid root for Electron's namespace sandbox fallback.
SETUID_ALLOWLIST = {"usr/lib/claude-desktop/chrome-sandbox"}
RISKY_SCRIPT = re.compile(
    r"(curl|wget)\b[^\n|]*\|\s*(ba|z)?sh|base64\s+-d|\beval\b|/dev/tcp/|nc\s+-e|"
    r"chmod\s+[0-7]*[67][0-7]{2}\s+/|\bsudo\b|rm\s+-rf\s+/(\s|$)"
)
URL_RE = re.compile(rb"https?://([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})")
CHUNK_BYTES = 1 << 20


@dataclass
class Report:
    blocking: list[str] = field(default_factory=list)
    info: list[str] = field(default_factory=list)

    def block(self, msg: str) -> None:
        self.blocking.append(msg)
        log.error("BLOCK: %s", msg)

    def note(self, msg: str) -> None:
        self.info.append(msg)
        log.info("%s", msg)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(CHUNK_BYTES):
            h.update(chunk)
    return h.hexdigest()


def run(*args: str, cwd: Path | None = None) -> str:
    return subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True).stdout


def check_archive_metadata(pkg: Path, rep: Report) -> None:
    setuid: list[str] = []
    with tarfile.open(pkg, "r:zst") as tf:
        for m in tf:
            name = m.name.removeprefix("./")
            if name != "usr" and not name.startswith(ALLOWED_PREFIXES):
                rep.block(f"path outside /usr: {name}")
            if m.uid != 0 or m.gid != 0:
                rep.block(f"non-root owner {m.uid}:{m.gid}: {name}")
            if m.ischr() or m.isblk() or m.isfifo():
                rep.block(f"device/fifo node: {name}")
            if m.mode & (stat.S_ISUID | stat.S_ISGID) and not m.isdir():
                setuid.append(f"{oct(m.mode)} {name}")
                if name not in SETUID_ALLOWLIST:
                    rep.block(f"unexpected setuid/setgid: {oct(m.mode)} {name}")
            if m.isdir() and m.mode & stat.S_ISGID:
                rep.block(f"setgid directory (build-dir leak): {oct(m.mode)} {name}")
            if m.mode & stat.S_IWOTH and not m.issym():
                rep.block(f"world-writable: {oct(m.mode)} {name}")
            if m.issym() or m.islnk():
                target = m.linkname
                base = "/" if m.islnk() else posixpath.dirname("/" + name)
                norm = posixpath.normpath(posixpath.join(base, target))
                if not norm.startswith("/usr/"):
                    rep.block(f"link resolves outside /usr: {name} -> {target} ({norm})")
    rep.note(f"setuid/setgid files: {setuid or 'none'}")


def check_install_script(root: Path, repo_install: Path, rep: Report) -> None:
    inst = root / ".INSTALL"
    if not inst.exists():
        rep.note(".INSTALL: none")
        return
    text = inst.read_text(errors="replace")
    ref = repo_install.read_text(errors="replace") if repo_install.exists() else ""
    if text == ref:
        rep.note(".INSTALL: byte-identical to repo packaging/arch/claude-desktop-extra.install")
    else:
        diff = "".join(
            difflib.unified_diff(ref.splitlines(True), text.splitlines(True), "repo", "pkg", n=1)
        )
        rep.block(f".INSTALL differs from repo copy:\n{diff}")
    for i, line in enumerate(text.splitlines(), 1):
        if RISKY_SCRIPT.search(line):
            rep.note(f".INSTALL:{i} pattern worth eyeballing: {line.strip()}")


def tree_hashes(base: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for p in base.rglob("*"):
        if p.is_symlink():
            out[str(p.relative_to(base))] = "link:" + str(p.readlink())
        elif p.is_file():
            # Exec bit is part of identity: a 0644 copy of an upstream 0755
            # helper is a broken install even with identical bytes.
            xbit = "x" if p.stat().st_mode & 0o111 else "-"
            out[str(p.relative_to(base))] = f"{sha256(p)}:{xbit}"
    return out


def hosts_in(base: Path) -> set[str]:
    hosts: set[str] = set()
    for p in base.rglob("*"):
        if p.is_file() and p.suffix in {".js", ".mjs", ".cjs", ".json", ".html"}:
            hosts.update(h.decode().lower() for h in URL_RE.findall(p.read_bytes()))
    return hosts


def compare_asar(name: str, up: Path, ours: Path, work: Path, rep: Report) -> None:
    a, b = work / f"asar-up-{name}", work / f"asar-ours-{name}"
    for d in (a, b):
        shutil.rmtree(d, ignore_errors=True)
    run("asar", "extract", str(up), str(a))
    run("asar", "extract", str(ours), str(b))
    ha, hb = tree_hashes(a), tree_hashes(b)
    added = sorted(set(hb) - set(ha))
    removed = sorted(set(ha) - set(hb))
    changed = sorted(k for k in set(ha) & set(hb) if ha[k] != hb[k])
    rep.note(f"{name}: +{len(added)} added, -{len(removed)} removed, ~{len(changed)} changed")
    for k in added:
        rep.note(f"  {name} added: {k}")
    for k in removed[:40]:
        rep.note(f"  {name} removed: {k}")
    for k in changed:
        rep.note(f"  {name} changed: {k}")
    new_hosts = sorted(hosts_in(b) - hosts_in(a))
    rep.note(f"{name}: network hosts only in patched code: {new_hosts or 'none'}")
    for k in added + changed:
        p = b / k
        if p.is_file() and p.suffix in {".node", ""} and p.read_bytes()[:4] == b"\x7fELF":
            rep.note(f"  {name}: native code added/changed: {k}")


def elf_hardening(path: Path) -> str:
    hdr = run("readelf", "-hlW", "--dyn-syms", str(path))
    dyn = subprocess.run(
        ["readelf", "-dW", str(path)], check=False, capture_output=True, text=True
    ).stdout
    pie = "DYN" in re.search(r"Type:\s+(\S+)", hdr).group(1)  # type: ignore[union-attr]
    static = "INTERP" not in hdr
    relro = "GNU_RELRO" in hdr
    now = "BIND_NOW" in dyn or re.search(r"FLAGS_1.*\bNOW\b", dyn) is not None
    stack = re.search(r"GNU_STACK\s+(?:\S+\s+){5}(\S+)", hdr)
    nx = stack is not None and "E" not in stack.group(1)
    return (
        f"PIE={'y' if pie else 'n'} static={'y' if static else 'n'} "
        f"RELRO={'full' if relro and now else 'partial' if relro else 'none'} "
        f"NX={'y' if nx else 'n'}"
    )


def compare_with_deb(root: Path, deb_root: Path, work: Path, rep: Report) -> list[Path]:
    app_rel = Path("usr/lib/claude-desktop")
    deb_app = next(
        (
            p
            for p in (
                deb_root / "usr/lib/claude-desktop",
                deb_root / "opt/Claude",
                deb_root / "usr/lib/claude",
            )
            if p.is_dir()
        ),
        None,
    )
    if deb_app is None:
        rep.block("cannot locate the app tree inside the upstream .deb")
        return []
    hp, hd = tree_hashes(root / app_rel), tree_hashes(deb_app)
    same = [k for k in hp if hd.get(k) == hp[k]]
    added = sorted(set(hp) - set(hd))
    removed = sorted(set(hd) - set(hp))
    changed = sorted(k for k in set(hp) & set(hd) if hp[k] != hd[k])
    rep.note(
        f"vs upstream .deb ({deb_app.relative_to(deb_root)}): {len(same)} identical, "
        f"{len(added)} added, {len(removed)} removed, {len(changed)} changed"
    )
    for k in added:
        rep.note(f"  added:   {k}")
    for k in removed:
        rep.note(f"  removed: {k}")
    for k in changed:
        rep.note(f"  changed: {k}")
    for k in changed:
        if k.endswith(".asar"):
            compare_asar(Path(k).name, deb_app / k, root / app_rel / k, work, rep)
    review = [root / app_rel / k for k in added + changed]
    others = [
        p
        for p in root.rglob("*")
        if p.is_file() and not p.is_symlink() and app_rel not in p.relative_to(root).parents
    ]
    rep.note(f"files outside {app_rel}: {len(others)}")
    for p in others:
        rep.note(f"  {p.relative_to(root)}")
    return review + others


def main(argv: list[str]) -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    if len(argv) < 5:
        print(__doc__, file=sys.stderr)
        return 2
    pkg, deb, work, repo_install = (Path(a).resolve() for a in argv[1:5])
    bridges = [Path(a).resolve() for a in argv[5:]]
    rep = Report()

    root, deb_x, deb_root = work / "pkg-root", work / "deb-x", work / "deb-root"
    for d in (root, deb_x, deb_root):
        shutil.rmtree(d, ignore_errors=True)
        d.mkdir(parents=True)
    # bsdtar refuses absolute paths and ".." members by default (-P not given).
    run("bsdtar", "-xf", str(pkg), "-C", str(root))
    run("bsdtar", "-xf", str(deb), "-C", str(deb_x))
    data = next(deb_x.glob("data.tar.*"))
    run("bsdtar", "-xf", str(data), "-C", str(deb_root))

    rep.note(f"package: {pkg.name} sha256={sha256(pkg)}")
    rep.note(f"upstream deb: {deb.name} sha256={sha256(deb)}")
    pkginfo = (root / ".PKGINFO").read_text()
    rep.note(
        "PKGINFO: "
        + "; ".join(
            ln
            for ln in pkginfo.splitlines()
            if ln.startswith(("pkgname", "pkgver", "depend", "packager"))
        )
    )
    check_archive_metadata(pkg, rep)
    check_install_script(root, repo_install, rep)
    review = compare_with_deb(root, deb_root, work, rep)

    for p in review:
        head = p.read_bytes()[:4] if p.is_file() else b""
        rel = p.relative_to(root)
        if head == b"\x7fELF":
            rep.note(f"ELF {rel}: {elf_hardening(p)}")
        elif head[:2] == b"#!":
            for i, line in enumerate(p.read_text(errors="replace").splitlines(), 1):
                if RISKY_SCRIPT.search(line):
                    rep.note(f"script {rel}:{i} pattern worth eyeballing: {line.strip()[:160]}")

    shipped = {p.name: sha256(p) for p in root.rglob("*-bridge") if p.is_file()}
    for b in bridges:
        got = shipped.get(b.name)
        want = sha256(b)
        if got is None:
            rep.block(f"bridge {b.name} not found in package")
        elif got != want:
            rep.block(f"bridge {b.name} differs from local build ({got[:12]} != {want[:12]})")
        else:
            rep.note(f"bridge {b.name}: matches local build {want[:16]}")

    (work / "report.json").write_text(
        json.dumps({"blocking": rep.blocking, "info": rep.info}, indent=2)
    )
    log.info("\n=== %d blocking finding(s) ===", len(rep.blocking))
    for b in rep.blocking:
        log.info("  - %s", b)
    return 1 if rep.blocking else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
