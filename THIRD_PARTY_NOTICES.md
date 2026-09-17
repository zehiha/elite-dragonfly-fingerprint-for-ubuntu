# Third-Party Notices

This repository contains original glue scripts and documentation under the MIT
license in `LICENSE`.

The libfprint patch is derived from and applies to third-party projects:

- Ubuntu Noble `libfprint` source package:
  `libfprint 1:1.94.7+tod1-0ubuntu5~24.04.8`
- libfprint upstream project, LGPL-2.1-or-later:
  https://gitlab.freedesktop.org/libfprint/libfprint
- Ubuntu source package files:
  - https://archive.ubuntu.com/ubuntu/pool/main/libf/libfprint/libfprint_1.94.7+tod1.orig.tar.bz2
  - https://archive.ubuntu.com/ubuntu/pool/main/libf/libfprint/libfprint_1.94.7+tod1-0ubuntu5~24.04.8.debian.tar.xz
  - https://archive.ubuntu.com/ubuntu/pool/main/libf/libfprint/libfprint_1.94.7+tod1-0ubuntu5~24.04.8.dsc
- Redrix crosfp driver work:
  https://github.com/iwinoid/redrix-crosfp-linux
- ChromeOS EC/fingerprint protocol references:
  https://chromium.googlesource.com/chromiumos/platform/ec/

The files under `patches/` should be treated as derived work under the licenses
of the projects they modify or incorporate. Preserve upstream copyright and
license notices when redistributing built binaries.
