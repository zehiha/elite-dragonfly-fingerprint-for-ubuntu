#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-}"
AUTO_ENABLE="${AUTO_ENABLE:-false}"
ARCH="${ARCH:-amd64}"
PKG="elite-dragonfly-fingerprint"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1789563840}"
export SOURCE_DATE_EPOCH
BUILD_DATE="$(date -Ru -d "@$SOURCE_DATE_EPOCH")"

usage() {
  cat <<'USAGE'
Usage:
  LIBFPRINT_SO=/path/to/libfprint-2.so.2.0.0 scripts/build-overlay-deb.sh --no-auto-enable
  LIBFPRINT_SO=/path/to/libfprint-2.so.2.0.0 scripts/build-overlay-deb.sh --auto-enable

If LIBFPRINT_SO is not set, this script runs:
  scripts/build-libfprint-crosfp.sh --quick

The resulting .deb installs a bundled libfprint under /usr/lib and a helper command.

Variants:
  --no-auto-enable  Build version 0.1.0. Install files only; do not activate fprintd.
  --auto-enable     Build version 0.1.1. Activate fprintd override on install.

Neither variant enrolls fingers or edits PAM.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-auto-enable)
      AUTO_ENABLE=false
      ;;
    --auto-enable)
      AUTO_ENABLE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -z "$VERSION" ]; then
  if [ "$AUTO_ENABLE" = true ]; then
    VERSION="0.1.1"
  else
    VERSION="0.1.0"
  fi
fi

mkdir -p "$BUILD_ROOT" "$DIST_DIR"

if [ -z "${LIBFPRINT_SO:-}" ]; then
  "$ROOT_DIR/scripts/build-libfprint-crosfp.sh" --quick
  LIBFPRINT_SO="$DIST_DIR/libfprint-2.so.2.0.0.crosfp"
fi

if [ ! -f "$LIBFPRINT_SO" ]; then
  echo "LIBFPRINT_SO does not exist: $LIBFPRINT_SO" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "$BUILD_ROOT/${PKG}-deb-XXXXXXXX")"
STAGE="$WORK_DIR/stage"

install -d -m 0755 "$STAGE/DEBIAN"
install -d -m 0755 "$STAGE/usr/lib/elite-dragonfly-fingerprint"
install -d -m 0755 "$STAGE/usr/bin"
install -d -m 0755 "$STAGE/usr/share/doc/$PKG/patches"
install -d -m 0755 "$STAGE/usr/share/man/man1"
install -d -m 0755 "$STAGE/usr/share/lintian/overrides"

install -m 0644 "$LIBFPRINT_SO" "$STAGE/usr/lib/elite-dragonfly-fingerprint/libfprint-2.so.2.0.0"
strip --strip-unneeded "$STAGE/usr/lib/elite-dragonfly-fingerprint/libfprint-2.so.2.0.0" 2>/dev/null || true
ln -s libfprint-2.so.2.0.0 "$STAGE/usr/lib/elite-dragonfly-fingerprint/libfprint-2.so.2"
ln -s libfprint-2.so.2.0.0 "$STAGE/usr/lib/elite-dragonfly-fingerprint/libfprint-2.so"

install -m 0755 "$ROOT_DIR/scripts/elite-dragonfly-fingerprint" "$STAGE/usr/bin/elite-dragonfly-fingerprint"
install -m 0644 "$ROOT_DIR/README.md" "$STAGE/usr/share/doc/$PKG/README.md"
install -m 0644 "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$STAGE/usr/share/doc/$PKG/THIRD_PARTY_NOTICES.md"
install -m 0644 "$ROOT_DIR/patches/ubuntu-noble-libfprint-crosfp.patch" "$STAGE/usr/share/doc/$PKG/patches/ubuntu-noble-libfprint-crosfp.patch"

cat > "$STAGE/usr/share/doc/$PKG/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: elite-dragonfly-fingerprint
Source: https://github.com/zehiha/elite-dragonfly-fingerprint-for-ubuntu

Files: scripts/* README.md RELEASE.md docs/*
Copyright: 2026 zehiha
License: MIT

Files: usr/lib/elite-dragonfly-fingerprint/libfprint-2.so.2.0.0 patches/*
Copyright: libfprint contributors, Ubuntu contributors, Redrix crosfp contributors
License: LGPL-2.1+
 See THIRD_PARTY_NOTICES.md for source package URLs and attribution.

License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

License: LGPL-2.1+
 This binary is built from Ubuntu's libfprint source package plus the included
 crosfp patch. The source project is LGPL-2.1-or-later. On Debian and Ubuntu
 systems, the full LGPL-2.1 text is available at:
/usr/share/common-licenses/LGPL-2.1
EOF
chmod 0644 "$STAGE/usr/share/doc/$PKG/copyright"

cat > "$STAGE/usr/share/doc/$PKG/changelog" <<EOF
$PKG ($VERSION) noble; urgency=medium

  * Experimental Redrix cros_fp libfprint overlay package.
  * Do not enroll fingers or edit PAM automatically.
EOF
if [ "$AUTO_ENABLE" = true ]; then
  cat >> "$STAGE/usr/share/doc/$PKG/changelog" <<'EOF'
  * Enable fprintd override automatically on install.
EOF
else
  cat >> "$STAGE/usr/share/doc/$PKG/changelog" <<'EOF'
  * Install files only; fprintd override activation remains manual.
EOF
fi
cat >> "$STAGE/usr/share/doc/$PKG/changelog" <<EOF

 -- zehiha <47032150+zehiha@users.noreply.github.com>  $BUILD_DATE
EOF
gzip -n -9 "$STAGE/usr/share/doc/$PKG/changelog"
chmod 0644 "$STAGE/usr/share/doc/$PKG/changelog.gz"

cat > "$WORK_DIR/elite-dragonfly-fingerprint.1" <<'EOF'
.TH ELITE-DRAGONFLY-FINGERPRINT 1
.SH NAME
elite-dragonfly-fingerprint \- control the experimental Redrix fprintd override
.SH SYNOPSIS
.B elite-dragonfly-fingerprint
.RI status
.br
.B sudo elite-dragonfly-fingerprint
.RI enable
.br
.B sudo elite-dragonfly-fingerprint
.RI disable
.SH DESCRIPTION
Controls an experimental fprintd library override for the HP Elite Dragonfly
Chromebook / Google Redrix fingerprint reader. It does not enroll fingers and
does not edit PAM.
EOF
gzip -n -9 < "$WORK_DIR/elite-dragonfly-fingerprint.1" > "$STAGE/usr/share/man/man1/elite-dragonfly-fingerprint.1.gz"
chmod 0644 "$STAGE/usr/share/man/man1/elite-dragonfly-fingerprint.1.gz"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: misc
Priority: optional
Architecture: $ARCH
Maintainer: zehiha <47032150+zehiha@users.noreply.github.com>
Depends: fprintd, libglib2.0-0, libgudev-1.0-0, libgusb2, libpixman-1-0, libc6
Description: experimental Redrix cros_fp libfprint override
 Experimental support package for the HP Elite Dragonfly Chromebook / Google
 Redrix fingerprint reader on Ubuntu. The package installs a private patched
EOF
if [ "$AUTO_ENABLE" = true ]; then
  cat >> "$STAGE/DEBIAN/control" <<'EOF'
 libfprint, activates the fprintd override, and provides a helper command. It
 does not enable PAM or enroll fingers automatically.
EOF
else
  cat >> "$STAGE/DEBIAN/control" <<'EOF'
 libfprint and provides a helper command. It does not activate fprintd, enable
 PAM, or enroll fingers automatically.
EOF
fi

if [ "$AUTO_ENABLE" = true ]; then
  cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

LIB_DIR="/usr/lib/elite-dragonfly-fingerprint"
OVERRIDE_DIR="/etc/systemd/system/fprintd.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/50-elite-dragonfly-fingerprint.conf"

case "$1" in
  configure)
    if [ -e "$LIB_DIR/libfprint-2.so.2" ]; then
      install -d -m 0755 "$OVERRIDE_DIR"
      cat > "$OVERRIDE_FILE" <<EOC
[Service]
Environment=LD_LIBRARY_PATH=$LIB_DIR
EOC
      if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload >/dev/null 2>&1 || true
        if command -v deb-systemd-invoke >/dev/null 2>&1; then
          deb-systemd-invoke restart fprintd.service >/dev/null 2>&1 || true
        else
          systemctl restart fprintd.service >/dev/null 2>&1 || true
        fi
      fi
    fi
    ;;
esac

exit 0
EOF
  chmod 0755 "$STAGE/DEBIAN/postinst"

  cat > "$STAGE/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

OVERRIDE_FILE="/etc/systemd/system/fprintd.service.d/50-elite-dragonfly-fingerprint.conf"

case "$1" in
  remove|deconfigure)
    if [ -f "$OVERRIDE_FILE" ]; then
      rm -f "$OVERRIDE_FILE"
    fi
    if command -v systemctl >/dev/null 2>&1; then
      systemctl daemon-reload >/dev/null 2>&1 || true
      if command -v deb-systemd-invoke >/dev/null 2>&1; then
        deb-systemd-invoke restart fprintd.service >/dev/null 2>&1 || true
      else
        systemctl restart fprintd.service >/dev/null 2>&1 || true
      fi
    fi
    ;;
esac

exit 0
EOF
  chmod 0755 "$STAGE/DEBIAN/prerm"

  cat > "$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e

OVERRIDE_DIR="/etc/systemd/system/fprintd.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/50-elite-dragonfly-fingerprint.conf"

case "$1" in
  purge)
    if [ -f "$OVERRIDE_FILE" ]; then
      rm -f "$OVERRIDE_FILE"
    fi
    rmdir "$OVERRIDE_DIR" 2>/dev/null || true
    if command -v systemctl >/dev/null 2>&1; then
      systemctl daemon-reload >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
EOF
  chmod 0755 "$STAGE/DEBIAN/postrm"

  cat > "$STAGE/usr/share/lintian/overrides/$PKG" <<'EOF'
# This package intentionally installs/removes a fprintd systemd drop-in and
# must reload systemd so the override takes effect immediately after install.
elite-dragonfly-fingerprint: maintainer-script-calls-systemctl
EOF
  chmod 0644 "$STAGE/usr/share/lintian/overrides/$PKG"
fi

find "$STAGE" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
dpkg-deb --build --root-owner-group "$STAGE" "$DIST_DIR/${PKG}_${VERSION}_${ARCH}.deb"
(cd "$DIST_DIR" && sha256sum "${PKG}"_*_"${ARCH}".deb > SHA256SUMS)
echo "Built: $DIST_DIR/${PKG}_${VERSION}_${ARCH}.deb"
