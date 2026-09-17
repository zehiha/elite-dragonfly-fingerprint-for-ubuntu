# Spike Notes

Question: can the Redrix `crosfp` libfprint driver be built against Ubuntu
Noble's `libfprint 1.94.7+tod1` source?

Verdict: partially validated.

Validated:

- Ubuntu source package extracted and patched.
- `crosfp.c` compiled after adding `stdint.h`.
- Redrix `PRP0001:01` was added to the driver's id table.
- `fp-context.c` was patched to match the `/dev/cros_fp` misc device path.
- Ubuntu TOD conditionals needed `#if HAVE_LIBFPRINT_TOD`, not `#ifdef`.
- `libfprint-2.so.2.0.0` linked successfully in a crosfp-only Meson build.
- Non-hardware tests passed: 2 OK, 27 skipped, 0 failed.

Not validated:

- Live fingerprint image capture.
- fprintd device listing with the patched library.
- Enrollment and verification.
- PAM login/sudo use.

Reason for stopping short: `/dev/cros_fp` is root-only, and live biometric
capture/enrollment should not be run implicitly from a packaging spike.
