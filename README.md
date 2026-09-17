# Elite Dragonfly Fingerprint for Ubuntu

Experimental Ubuntu support work for the fingerprint reader in the HP Elite
Dragonfly Chromebook / Google Redrix.

This is not an official HP, Google, Ubuntu, libfprint, or fprintd project. It is
a source/patch project for rebuilding Ubuntu Noble's `libfprint` with a
ChromeOS EC fingerprint driver (`crosfp`) for `/dev/cros_fp`.

## Status

Current status: build-validated, runtime not fully validated.

Validated locally:

- Hardware path exists as `/dev/cros_fp`.
- Stock `fprintd-list "$USER"` reports `No devices available`.
- Ubuntu Noble `libfprint 1.94.7+tod1-0ubuntu5~24.04.8` can be patched with
  the `crosfp` driver.
- A `crosfp`-only Meson build produced `libfprint-2.so.2.0.0`.
- Non-hardware unit tests passed: 2 OK, 27 skipped, 0 failed.

Not validated yet:

- Live enrollment with `fprintd-enroll`.
- Live verification with `fprintd-verify`.
- PAM login/sudo integration.

The package/build scripts deliberately do not enable PAM fingerprint login.

## Tested Machine

- DMI: `Google Redrix rev3`
- OS: Ubuntu 24.04.5 Noble
- Kernel: `6.17.0-1025-oem`
- Fingerprint node: `/dev/cros_fp`
- ACPI/sysfs path: `spi-PRP0001:01`, `cros-ec-spi`
- Current stock behavior: fprintd sees no fingerprint device

This is not a promise that every "Elite Dragonfly" model is supported. The
target is the Chromebook/Redrix hardware path.

## Safety and Privacy

Fingerprint data is sensitive.

This driver exposes raw captured fingerprint images to libfprint. Enrollment
templates and matching are handled by libfprint/fprintd on the host. Do not
assume templates are sealed inside the fingerprint MCU like ChromeOS biod.

On Linux, fingerprint templates are normally stored under `/var/lib/fprint`.
Use full-disk encryption and keep fprintd state permissions tight. Do not enable
fingerprint login for sudo, GDM, or system auth until enrollment and negative
verification tests are proven on your own machine.

Use at your own risk.

## Build

Quick build check:

```bash
./scripts/build-libfprint-crosfp.sh --quick
```

Build local Debian packages from Ubuntu source:

```bash
./scripts/build-libfprint-crosfp.sh --debian
```

If build dependencies are missing, the script prints the missing packages. To
let it install the known dependency set:

```bash
./scripts/build-libfprint-crosfp.sh --install-deps --debian
```

Build output goes to `dist/`.

## Optional Overlay Package

For easier testing, this repo can also build an experimental overlay `.deb`.
It installs a patched `libfprint-2.so` under
`/usr/lib/elite-dragonfly-fingerprint` and a helper command:

```bash
LIBFPRINT_SO=dist/libfprint-2.so.2.0.0.crosfp ./scripts/build-overlay-deb.sh --no-auto-enable
LIBFPRINT_SO=dist/libfprint-2.so.2.0.0.crosfp ./scripts/build-overlay-deb.sh --auto-enable
```

This builds two intended variants:

- `0.1.0`: installs the patched library and helper command only. It does not
  activate `fprintd` automatically.
- `0.1.1`: installs the same files and activates the `fprintd` override during
  package installation.

After installing either package, check it with:

```bash
elite-dragonfly-fingerprint status
```

Disable or re-enable the override manually with:

```bash
sudo elite-dragonfly-fingerprint disable
sudo elite-dragonfly-fingerprint enable
```

This is intentionally separate from PAM enrollment.

## Install

Do not install blindly. Review the produced package list first:

```bash
ls -1 dist/*.deb
```

For the normal fprintd path, the important runtime package is the rebuilt
`libfprint-2-2` package. Depending on your installed Ubuntu packages, you may
also need the matching TOD package from the same build.

If you use the overlay package instead, install only the
`elite-dragonfly-fingerprint_*.deb` package. The `0.1.0` package keeps
activation manual; the `0.1.1` package activates the fprintd override on
install. Neither package enrolls fingers or edits PAM.

After installing rebuilt packages:

```bash
sudo systemctl restart fprintd.service
fprintd-list "$USER"
```

Only if the device appears should you continue with enrollment:

```bash
fprintd-enroll "$USER"
fprintd-verify "$USER"
```

Do not enable PAM fingerprint authentication until an enrolled finger succeeds
and an unenrolled finger fails.

## Disable

Reinstall Ubuntu's stock packages:

```bash
sudo apt install --reinstall libfprint-2-2 libfprint-2-tod1 fprintd libpam-fprintd
sudo systemctl restart fprintd.service
```

Then check:

```bash
fprintd-list "$USER"
```

## Diagnostics

Read-only diagnostics:

```bash
./scripts/diagnose-fingerprint.sh
```

The diagnostic script does not capture fingerprint images and does not enroll
or verify fingers.

## Notes

This was assembled with OpenClaw and AI assistance. Treat it as experimental
hardware enablement work, not a polished distribution package.

The repo keeps source patches and build scripts in git. Built `.deb` files
belong in GitHub Releases, not in the main branch.
