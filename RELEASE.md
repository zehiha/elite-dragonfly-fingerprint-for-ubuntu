# Release Notes - v0.1.0

First experimental source release for the HP Elite Dragonfly Chromebook /
Google Redrix fingerprint reader on Ubuntu Noble.

## What Is Included

- Patch for Ubuntu Noble `libfprint 1.94.7+tod1-0ubuntu5~24.04.8`.
- Adds a `crosfp` image driver for ChromeOS EC fingerprint hardware exposed as
  `/dev/cros_fp`.
- Adds Redrix `PRP0001:01` matching for the local machine.
- Adds build and diagnostic scripts.
- Adds an optional overlay `.deb` package:
  - `0.1.0`: installs the patched libfprint under
    `/usr/lib/elite-dragonfly-fingerprint` without activating fprintd.

## Validation

- The crosfp-only Meson build completed locally.
- `libfprint-2.so.2.0.0` linked successfully.
- Non-hardware tests: 2 passed, 27 skipped, 0 failed.

Live enrollment and verification are not validated in this release.

## Warning

This is experimental biometric software. It was assembled with OpenClaw and AI
assistance and should be used only by people comfortable recovering their
system if fprintd/libfprint breaks.

This release does not enable PAM automatically, does not enroll fingers
automatically, and does not activate the fprintd override during package
installation. Activation is manual:

```bash
sudo elite-dragonfly-fingerprint enable
```

## Release Asset

`elite-dragonfly-fingerprint_0.1.0_amd64.deb`

SHA256:

`fe76914fab93dfc4430f0e87cb9fbd1333eb63271765586ed49e42fd472fb6a3`
