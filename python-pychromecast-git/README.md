# python-pychromecast-git

VCS build of [PyChromecast](https://github.com/home-assistant-libs/pychromecast)
from upstream `master`. It `provides` and `conflicts` with `python-pychromecast`,
so it satisfies PhotoQt's dependency on that name.

## Why this exists

`extra/python-pychromecast` packages the 14.0.10 release. The verified revision
here (`9527bc4`, 2026-10-13) is 86 commits past that tag. Besides dependency
bumps, the newer commits include an HTTP fallback when determining the cast type
over HTTPS fails, new known-device entries, and a fix for an infinite loop when
reconnect raises.

The AUR already has `python-pychromecast-git`, but its last update was
2022-12 (13.0.4). Its `package()` symlinks
`PyChromecast-<ver>.dist-info/LICENSE`. Current wheels install
`pychromecast-<ver>.dist-info/licenses/LICENSE` instead, so that symlink would
dangle. This recipe installs the license from the source tree.

## Differences from `extra/python-pychromecast`

- **`python-requests` declared.** `config.py` and `controllers/youtube.py`
  import `requests` at module level. Upstream lists only `casttube`,
  `protobuf` and `zeroconf` and gets `requests` transitively through
  `casttube`. namcap reports it as "implicitly satisfied".
- **`--skip-dependency-check`.** `[build-system] requires` caps
  `setuptools<85` and `wheel<0.49`. Dependabot raises those caps after Arch
  ships the new versions, so the check eventually fails a build that would
  otherwise succeed. `wheel` isn't needed at all: setuptools 70.1 and newer
  ship `bdist_wheel`.
- **`check()` added.** Upstream's suite is one import test (`tests/test_init.py`).
  Plugin autoload is disabled so unrelated system-wide pytest plugins don't load.
  On the packager's host that cut the run from 2.4 s to 0.13 s.
- **Bytecode levels explicit.** `--compile-bytecode 0 --compile-bytecode 1`,
  matching the other Python recipes here.

## Host tuning

None applies. The package is pure Python (`arch=any`) with no extension modules,
so `CFLAGS`, `-march`, and LTO in `makepkg.conf` have nothing to act on.

## namcap

`namcap PKGBUILD` is clean. On the built package, namcap reports
`python-plexapi` as a missing dependency. It isn't one: every `plexapi`
import in `controllers/plex.py` is inside `if TYPE_CHECKING:`.

## Upstream deprecations

setuptools warns about the TOML-table `project.license`, the license
classifiers, and `setup.cfg`'s `[wheel] universal = 1`, which also tags the
wheel `py2.py3`. setuptools announces these as build errors after
**2027-02-18**. They need fixing upstream; this recipe doesn't patch them.

## Not claimed

- **No clean-chroot build.** `makepkg --cleanbuild --clean --force --check` on
  the packager's host only; `pkgctl build` wasn't run.
- **No device tested.** The only test is upstream's import test plus a manual
  import of the `config`, `youtube` and `plex` modules. Nothing was cast to a
  Chromecast.
- **PhotoQt not exercised against this build.** The `provides` entry only
  matches the dependency name. A `pacman -Up --print` dry run resolved without
  errors, but that doesn't prove the full conflict handling. The equivalent
  `extra`-named build of the same revision was installed and imported, but
  PhotoQt's casting feature wasn't used.
- **Moving target.** The verified revision is `9527bc4`. A later upstream
  setuptools cap or dependency change could need recipe changes.

## Build and install

```bash
cd python-pychromecast-git
makepkg -si
```

pacman will offer to replace `python-pychromecast` because of the conflict.
