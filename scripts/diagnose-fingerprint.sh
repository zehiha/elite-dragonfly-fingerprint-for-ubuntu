#!/usr/bin/env bash
set -euo pipefail

section() {
  printf '\n== %s ==\n' "$1"
}

run_optional_root() {
  if sudo -n true 2>/dev/null; then
    sudo "$@"
  else
    printf 'skipped, sudo password required:'
    printf ' %q' "$@"
    printf '\n'
  fi
}

section "System"
lsb_release -a 2>/dev/null || true
uname -a
cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true
cat /sys/class/dmi/id/product_name 2>/dev/null || true
cat /sys/class/dmi/id/product_version 2>/dev/null || true

section "Fingerprint nodes"
ls -l /dev/cros_fp /dev/cros_ec 2>/dev/null || true
stat -c '%a %U %G %n' /dev/cros_fp /dev/cros_ec 2>/dev/null || true
udevadm info -q property -n /dev/cros_fp 2>/dev/null | sort || true
readlink -f /sys/class/chromeos/cros_fp 2>/dev/null || true

section "ACPI / sysfs hints"
find /sys/bus/acpi/devices -maxdepth 2 -type f \( -name hid -o -name path -o -name modalias \) \
  -exec sh -c 'printf "%s: " "$1"; cat "$1"' sh {} \; 2>/dev/null | grep -Ei 'PRP0001|CRFP|cros|finger|fp' || true

section "Packages"
dpkg-query -W fprintd libfprint-2-2 libfprint-2-tod1 libpam-fprintd 2>/dev/null || true

section "fprintd"
systemctl --no-pager --full status fprintd.service 2>&1 || true
fprintd-list "${SUDO_USER:-$USER}" 2>&1 || true

section "ectool read-only hints"
if command -v ectool >/dev/null 2>&1; then
  run_optional_root ectool --name=cros_fp fpinfo || true
  run_optional_root ectool --name=cros_fp fpmode || true
  run_optional_root ectool --name=cros_fp fpstats || true
else
  echo "ectool not found"
fi

section "Done"
echo "No fingerprint image capture, enrollment, verification, or PAM change was performed."
