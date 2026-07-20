# `python-installer`

Temporary Arch package for [`installer` 1.0.1](https://github.com/pypa/installer), based on Arch's official `python-installer` recipe.

The configured Arch repositories currently provide `python-installer` 1.0.0, while the AUR `python-rapidocr` package requires `python-installer>=1.0.1` at build time. This bridge closes that version gap so `headroom-git` and its full OCR dependency set can resolve.

Build and install this bridge before asking paru to resolve Headroom. Passing both
directories to one paru invocation is insufficient: paru may build the bridge
without installing it before checking `python-rapidocr`'s versioned dependency.

From the SAUR repository root:

These commands require an installed and configured `paru`.

```bash
(
  cd python-installer &&
    makepkg -si --needed --force
) &&
  pacman -T 'python-installer>=1.0.1' &&
  paru -Bi ./headroom-git
```

`pacman -T` prints nothing and exits successfully when the bridge is active.

Remove this recipe after the configured repositories ship `python-installer>=1.0.1`; the repository package should then replace this package normally during an upgrade.
