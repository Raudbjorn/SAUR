# `xorg-server-git`

Arch VCS package for the [X.Org server](https://gitlab.freedesktop.org/xorg/xserver) from upstream `master`, split into the usual six packages:

| Package | Contents |
| --- | --- |
| `xorg-server-git` | `Xorg`, `Xorg.wrap` (setuid), `modesetting`, GLX/glamor and the other modules |
| `xorg-server-common-git` | Files shared with Xephyr, Xnest and Xvfb |
| `xorg-server-devel-git` | Headers, `xorg-server.pc`, `xorg-server.m4` |
| `xorg-server-xephyr-git` | Xephyr |
| `xorg-server-xnest-git` | Xnest |
| `xorg-server-xvfb-git` | Xvfb and `xvfb-run` |

Xwayland is disabled (`-D xwayland=false`) because this recipe does not package it; keep using `extra/xorg-xwayland`.

The recipe descends from the AUR [`xorg-server-git`](https://aur.archlinux.org/packages/xorg-server-git) by JustKidding and Yurii Kolesnykov, which is based on `extra/xorg-server`.

## Changes from the AUR recipe

- **`pkgver()` rewritten.** Upstream now tags `server-26.1-branchpoint` instead of `xorg-server-X.Y.Z`. The old function produced `server.26.1.branchpoint.r91...`, which `vercmp` ranks *below* the repository's 21.1.25. The base version now comes from `meson.build`, giving `26.1.99.1.r91.geae2c2107`.
- **ABI `provides` corrected.** The old recipe advertised `X-ABI-VIDEODRV_VERSION=25.3`, `XINPUT=24.4`, `EXTENSION=10.0`. This source enforces 28.0, 26.0 and 11.0. The values are now variables at the top of the file, and `prepare()` fails the build if they differ from `hw/xfree86/common/xf86Module.h`.
- **Hardening workaround applied to every occurrence.** `${CFLAGS/-fno-plt}` only removed the first match; it is now `${CFLAGS//-fno-plt}`, and likewise for `-Wl,-z,now`. Modules resolve server symbols at load time, so the result is partial RELRO by design (namcap reports it).
- **`mesa-libgl` makedepend replaced by `libglvnd`.** `mesa-libgl` is only a virtual provide today and made makepkg ask which of several providers to use.
- **`_install` copies with `tar --no-acls --no-xattrs`.** `cp -a` and `cp --preserve=mode` try to copy ACLs and fail with `ENODATA` on mergerfs. `tar` still preserves the setuid bit on `Xorg.wrap`.
- **Missing runtime dependencies added:** `libbsd` and `libmd` (all binary packages), `pixman` (`-devel`, needed by `xorg-server.pc`). Found with namcap.
- `meson compile` and `meson install --destdir` replace direct `ninja` calls; `check()` prints test logs on failure.

## Driver ABI: rebuild every `xf86-*` driver

Input and video drivers are loaded by the server and are refused unless their ABI major matches. This package provides `X-ABI-VIDEODRV_VERSION=28.0`, `X-ABI-XINPUT_VERSION=26.0` and `X-ABI-EXTENSION_VERSION=11.0`, so the repository drivers (video 25, xinput 24) conflict with it and pacman will not install the server alongside them.

If a display manager that starts an X11 greeter (SDDM does by default) is used, a missing or mismatched input driver means no keyboard or mouse at the login screen. Install the server and rebuilt drivers in **one** pacman transaction:

```bash
pacman -U xorg-server*-git-*.pkg.tar.zst xf86-input-libinput-git-*.pkg.tar.zst ...
```

The driver recipes used for this are not part of this repository. When building them, pass `sdkdir=/usr/include/xorg` (`-D sdkdir=...` for meson, `--with-sdkdir=...` for autotools); otherwise the generated `.pc` files embed the build-time include path.

## Validate

```bash
bash -n PKGBUILD
makepkg --printsrcinfo > .SRCINFO
makepkg --cleanbuild --clean --force --check
namcap PKGBUILD
namcap ./*.pkg.tar.*
```

Expected namcap output: `lacks FULL RELRO` on the server and modules (intentional, see above), and `custom is not a valid SPDX license identifier` (inherited `license=('custom')`, not changed here).
