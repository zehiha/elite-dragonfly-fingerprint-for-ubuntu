#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT_DIR/patches/ubuntu-noble-libfprint-crosfp.patch"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"

SRC_NAME="libfprint"
SRC_VERSION="1.94.7+tod1"
UBUNTU_REV="0ubuntu5~24.04.8"
LOCAL_SUFFIX="crosfp1"
LOCAL_VERSION="1:${SRC_VERSION}-${UBUNTU_REV}+${LOCAL_SUFFIX}"

BASE_URL="https://archive.ubuntu.com/ubuntu/pool/main/libf/libfprint"
ORIG="libfprint_${SRC_VERSION}.orig.tar.bz2"
DEBIAN_TAR="libfprint_${SRC_VERSION}-${UBUNTU_REV}.debian.tar.xz"
DSC="libfprint_${SRC_VERSION}-${UBUNTU_REV}.dsc"

INSTALL_DEPS=false
MODE="quick"

usage() {
  cat <<'USAGE'
Usage:
  scripts/build-libfprint-crosfp.sh [--quick|--debian] [--install-deps]

Modes:
  --quick       Build only a crosfp-enabled libfprint shared library with Meson.
  --debian      Build patched Ubuntu Debian packages with dpkg-buildpackage.

Options:
  --install-deps  Install the known Ubuntu build dependencies with apt.

Output:
  build/         downloaded and patched source trees
  dist/          built artifacts
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick)
      MODE="quick"
      ;;
    --debian)
      MODE="debian"
      ;;
    --install-deps)
      INSTALL_DEPS=true
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

download() {
  local name="$1"
  local url="$BASE_URL/$name"

  if [ -f "$BUILD_ROOT/$name" ]; then
    return
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -fL "$url" -o "$BUILD_ROOT/$name"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$BUILD_ROOT/$name" "$url"
  else
    echo "Need curl or wget to download Ubuntu source files." >&2
    exit 1
  fi
}

verify_sources() {
  (
    cd "$BUILD_ROOT"
    sha256sum -c <<EOF
7b3421bc73a1905f1a6d3e49c5e0feeb9827b83857c78ca6882ac230ae5d759a  $ORIG
14b49caf1c4ed2c4d814c35dac88d3c33622d3452ed2a8d044c5561d02edf23d  $DEBIAN_TAR
35682f7067fb573406181e26b61e013a23e6a09c04f8982985e337803266b16e  $DSC
EOF
  )
}

install_deps() {
  sudo apt-get update
  sudo apt-get install -y \
    build-essential \
    debhelper \
    dpkg-dev \
    meson \
    ninja-build \
    pkg-config \
    patch \
    curl \
    gobject-introspection \
    gtk-doc-tools \
    libcairo2-dev \
    libgirepository1.0-dev \
    libglib2.0-dev \
    libgudev-1.0-dev \
    libgusb-dev \
    libjson-glib-dev \
    libnss3-dev \
    libpixman-1-dev \
    libusb-1.0-0-dev \
    systemd-dev \
    python3 \
    python3-cairo \
    python3-gi \
    umockdev
}

prepare_source() {
  local dest="$BUILD_ROOT/${SRC_NAME}-${SRC_VERSION}-${LOCAL_SUFFIX}"

  if [ -e "$dest" ]; then
    echo "Build source already exists: $dest" >&2
    echo "Move it aside or set BUILD_ROOT to a fresh directory." >&2
    exit 1
  fi

  mkdir -p "$BUILD_ROOT" "$DIST_DIR"
  download "$ORIG"
  download "$DEBIAN_TAR"
  download "$DSC"
  verify_sources >&2

  (
    cd "$BUILD_ROOT"
    dpkg-source -x "$DSC" "${SRC_NAME}-${SRC_VERSION}-${LOCAL_SUFFIX}"
  ) >&2

  patch -p1 -d "$dest" < "$PATCH_FILE" >&2

  {
    echo "libfprint (${LOCAL_VERSION}) noble; urgency=medium"
    echo
    echo "  * Local Redrix crosfp build."
    echo "  * Add ChromeOS EC fingerprint driver for /dev/cros_fp."
    echo
    echo " -- zehiha <47032150+zehiha@users.noreply.github.com>  $(date -R)"
    echo
    cat "$dest/debian/changelog"
  } > "$dest/debian/changelog.new"
  mv "$dest/debian/changelog.new" "$dest/debian/changelog"

  printf '%s\n' "$dest"
}

if [ "$INSTALL_DEPS" = true ]; then
  install_deps
fi

SRC_DIR="$(prepare_source)"

if [ "$MODE" = "quick" ]; then
  meson setup "$SRC_DIR/build-crosfp" "$SRC_DIR" \
    -Ddrivers=crosfp \
    -Ddoc=false \
    -Dintrospection=false \
    -Dinstalled-tests=false \
    -Dudev_rules=disabled \
    -Dudev_hwdb=disabled \
    -Dtod=false
  meson compile -C "$SRC_DIR/build-crosfp"
  meson test -C "$SRC_DIR/build-crosfp" --no-rebuild --print-errorlogs
  install -m 0755 "$SRC_DIR/build-crosfp/libfprint/libfprint-2.so.2.0.0" "$DIST_DIR/libfprint-2.so.2.0.0.crosfp"
  echo "Quick build artifact: $DIST_DIR/libfprint-2.so.2.0.0.crosfp"
  exit 0
fi

(
  cd "$SRC_DIR"
  export DEB_BUILD_OPTIONS="nocheck nodoc"
  export DEB_BUILD_PROFILES="nodoc nogir nocheck"
  dpkg-checkbuilddeps -P nodoc,nogir,nocheck || {
    echo
    echo "Missing build dependencies. Re-run with --install-deps or install the listed packages." >&2
    exit 1
  }
  dpkg-buildpackage -us -uc -b
)

find "$BUILD_ROOT" -maxdepth 1 -type f \( -name '*.deb' -o -name '*.buildinfo' -o -name '*.changes' \) -exec cp -p {} "$DIST_DIR/" \;
echo "Debian build artifacts copied to: $DIST_DIR"
