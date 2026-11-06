# trid

[TrID](https://mark0.net/soft-trid-e.html), a file-type identifier that
matches binary signatures against a definitions database. Based on the AUR
`trid` recipe (Jesse Jaara) at 2.48-2; upstream is still 2.48.

## Changes from the AUR recipe

- `trid` passed its arguments as unquoted `$*`, so a filename containing
  spaces was split into several nonexistent paths. The wrapper now `exec`s
  with `"$@"`.
- Sources and the definitions update use HTTPS. Upstream's `--update`
  fetched `triddefs.zip` over plain HTTP and verified it only against an MD5
  fetched over the same channel, which authenticates nothing; `prepare()`
  rewrites both URLs in `trid.py`.
- `update-trid-defs` stops when the download fails instead of going on to
  regenerate the cache from the old database.
- `update-trid-defs.service` had `After=network-online.target` without
  `Wants=`, which orders against the target but never pulls it in.
- The licence directory held a symlink to `readme.txt`, which contains no
  licence terms; `license.txt` is installed instead, and the commercial term
  is the SPDX-valid `LicenseRef-trid-commercial`.

## Host tuning

None applies. TrID is one Python script and the package is `arch=any`, so
`CFLAGS` and `-march` have nothing to act on. Byte-compiling was measured and
rejected: compiling `trid.py` costs about 3 ms of a roughly 137 ms run, and
using the bytecode would mean replacing the script launcher with `python -m`.

The optional `python-stringzilla` is the only native component. It builds
every x86 SIMD tier and dispatches at run time (Zen 4 selects the AVX-512
`icelake` kernels), so the speedup comes from installing it rather than from
tuning it. On 2,000 files from `/usr/bin`, a run took 2.1–2.7 s with
StringZilla 5.3.1 and 4.2–4.7 s without, with identical output.

## Build

```bash
makepkg -si
sudo update-trid-defs
```

`trid` refuses to run until `update-trid-defs` has downloaded the definitions
to `/var/lib/trid` and generated the cache. To keep them current:

```bash
sudo systemctl enable --now update-trid-defs.timer
```

## Not verified

- Not built in a clean chroot; `makepkg --cleanbuild` only.
- The benchmark used a locally built StringZilla 5.3.1; AUR
  `python-stringzilla` was at 5.1.2 and was not measured.
- The 2,000-file sample came from `/usr/bin`, which is mostly ELF; other file
  types were not timed.
- `namcap` warns that `/var/lib/trid` is empty (it is filled at run time),
  that `stringzilla` is optional, and that `sh` is satisfied by bash. All
  three are expected.
