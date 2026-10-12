# Weazlterm status and review evidence

Updated 2026-10-11. **A PowerPC Tiger release candidate is built at
`../release/weazlterm.app` (0.1.1, build 2). The user reports a successful interactive SSH
session from the G4 to this development box, with working colors. The
original hostname connection problem was identified by the user as DNS.**

## Artifact and build evidence

The bundle contains the native AppKit terminal, the supplied ICNS, OpenSSH
portable 10.6p1 `ssh` and `ssh-keygen`, upstream license text, and fail-closed
`scp`/`sftp` placeholders. `Info.plist` sets the minimum system version to
10.4. The app launches Bash from the system and routes ordinary `ssh` and
`ssh-keygen` commands to the bundled helpers.

Build host: x86-64 Linux. Target: 32-bit big-endian PowerPC, Mach-O, compiled
for G3-compatible instructions and linked against the Mac OS X 10.4u SDK.
The cross-link recipe passes `-macosx_version_min 10.4` and uses strict
undefined-symbol checking. The app imports Cocoa, AppKit, Foundation,
CoreServices, Tiger `libobjc`, and Tiger `libSystem`; each SSH helper imports
only Tiger `libSystem`. These checks establish cross-build structure and
dependencies, not successful loading by Tiger's dynamic loader.

The final bundle tree SHA-256 is
`085353e72232014aeb78e92706c8db50d6ac504e9151b2c217419bee972539bb`.
The executable string scan found no build-machine paths. A deterministic
file-by-file record is in `build/release-validation-ssh-path-fix.log`.

| Check | Result and retained evidence |
| --- | --- |
| Terminal/PTy/shell tests | `make test sanitize` passed on Linux; `build/tests-ssh-path-fix.log` |
| Objective-C frontend | GCC 15.2 `cc1obj` built for the Darwin 8 PPC target; `build/gcc-objc-build6.log` |
| OpenSSH target build | OpenSSH 10.6p1 `ssh` and `ssh-keygen` are PPC Mach-O, strict-linked and source-path-remapped; `build/ssh-ppc-release.log` |
| App target build | PPC Mach-O executable, Tiger frameworks, bundle staged; `build/app-ppc-ssh-path-fix.log` |
| Bundle metadata and icon | Python `plistlib` parses the plist; packaged icon bytes match the supplied ICNS exactly (SHA-256 `b564e5f55842cd46e9f5d423935252f3ef81d198c962341ee300624d458ffe84`) |
| Bundled algorithm code | PPC helper contains OpenSSH 10.6p1 strings for Ed25519, RSA-SHA2, ECDSA, sntrup761/Curve25519 and ChaCha20-Poly1305; this is compile evidence, not an executed handshake |
| Shell routing | Host regression tests cover profile/rc PATH changes, aliases, functions, command hashes, bundle paths with spaces, missing SSH, and fail-closed `command scp` |

OpenSSH source archive SHA-256:
`a9dc9565dffe8640f64d863cd29a32bc4a3dbdec0566a7fc44c5d6ee767d5f39`.
The release app does not include the Linux host executable in `build/ssh/`.

## SSH interoperability evidence and limits

The separate Linux OpenSSH candidate negotiated modern algorithms with
`weazltunes.teralab.local` and stopped at strict host-key verification. The
server identity was not independently verified; no host key was accepted and
no user authentication occurred. The host-side probe is not a substitute for
running the bundled PPC client.

The G4, Tiger runtime, and USB launch path were unavailable in this build
environment. The PPC executables have not run here. The terminal is an early
xterm-compatible subset: it has no scrollback or text selection/copy, and
full-screen TUI compatibility has not been established. `scp` and `sftp` are
not supported and intentionally fail closed. Paste and resize are present in
the source but still need hardware interaction tests.

## Workbook gate tracking

| Step | State | Evidence still needed |
| --- | --- | --- |
| 1 Baseline | Host tests passed | Review complete retained logs and provenance |
| 2 Tiger toolchain | PPC cross-build works | Launch a trivial C program and AppKit window on Tiger |
| 3 Modern SSH | User reports successful G4 SSH session to development box | Record negotiated algorithms; complete key tests and original-host test |
| 4 Bundled command resolution | Startup fix followed by successful user-reported G4 SSH session | Retain explicit client version/path evidence |
| 5 Core and PTY | Host regression and sanitizers pass | Test Tiger lifecycle, job control, TUI behavior and performance |
| 6 Native interface | PPC Mach-O bundle built | Launch, inspect input/rendering, close and reopen on Tiger |
| 7 TERM interoperability | `xterm-256color` is advertised | Exercise local Bash and remote full-screen programs; address missing terminal behavior |
| 8 Icon | Supplied ICNS is in the bundle | Verify Finder and Dock rendering on Tiger |
| 9 Packaging | `release/weazlterm.app` exists | Copy to USB, relocate, launch read-only/with spaces and inspect dependencies on Tiger |
| 10 Hardware acceptance | User reports working G4 SSH session and colors | Complete the G4 test plan in `WORKBOOK.md` and record measured results |

Before accepting a first host key, compare its fingerprint with a trusted
source. Do not weaken host-key checking or change server configuration to make
the test pass.

## 0.1.1 SSH path fix (2026-10-11)

The user reported “bundled ssh is missing: refusing the system ssh fallback”
on the PPC. The app had passed its native executable-file check. Its managed
rc then used `BASH_SOURCE[0]`, absent in Bash 2.05b, and resolved the helper
directory as `/Helpers`. This was a shell lookup bug, not missing packaging.

`resources/shell/weazlterm.bashrc` now derives the helper directory from
`WEAZLTERM_RC`, the absolute NSBundle resource path already exported by
`src/main.m`. No current-directory assumption, newer Bash feature, system SSH
fallback, or user profile edits are involved. `resources/Info.plist` identifies
0.1.1/build 2. `tests/test_shell_resolution.sh` accepts `WEAZLTERM_TEST_BASH`
and `WEAZLTERM_TEST_RC` overrides and also tests actual interactive rc startup.

Linux evidence: GNU Bash 2.05b was built locally from
https://ftp.gnu.org/gnu/bash/bash-2.05b.tar.gz under `build/bash-compat/`.
Configure used `CC='gcc -std=gnu89 -fcommon -Wno-implicit-function-declaration
-Wno-int-conversion' ./configure --without-bash-malloc`; serial `make` succeeded
(the initial parallel make raced generation of version.h). This old Bash is
a host-only test tool; it is not packaged or installed on the G4.

Commands and results:

- `make test sanitize`: terminal, PTY, shell and sanitizer checks passed;
  `build/tests-ssh-path-fix.log`.
- `WEAZLTERM_TEST_BASH="$PWD/build/bash-compat/bash-2.05b/bash"
  WEAZLTERM_TEST_RC="$PWD/build/bash-compat/original.bashrc"
  sh tests/test_shell_resolution.sh`: original startup fails with exit 126;
  `build/bash-compat/before.log`. A direct invocation also reproduces the
  exact reported error in `build/bash-compat/reproduced-error.log`.
- The same command with `WEAZLTERM_TEST_RC` pointing to
  `release/weazlterm.app/Contents/Resources/shell/weazlterm.bashrc` passes all
  four shell checks: profile overrides/spaces, interactive startup,
  unsupported scp, and missing-helper refusal; `build/bash-compat/after.log`.
- `sh scripts/build-app-ppc.sh`: rebuilt the complete bundle after preserving
  the previous artifact as `build/weazlterm-before-ssh-path-fix.app`;
  `build/app-ppc-ssh-path-fix.log`.
- Artifact checks confirm all three native executables are PPC Mach-O with
  executable bits, the supplied icon and fixed rc match source, minimum OS
  is 10.4, and no build-machine path appears in those binaries;
  `build/release-validation-ssh-path-fix.log`.

At the time of this fix, the next check was G4 SSH execution. The user
subsequently reported success, as recorded below.


## G4 SSH session confirmed by user (2026-10-11)

After the 0.1.1 startup fix, the user reported: “ok dns issue - i just sshd
into this box and its flawless - even the colors work”. In the ongoing G4
hardware test, this establishes user-reported successful interactive SSH to
the development box and working color rendering. The earlier silent attempt
to the original hostname was identified by the user as a DNS issue.

No new build or code change was needed. The release artifact and digest above
are unchanged. The exact destination address, negotiated algorithms, client
version output, authentication method, and USB launch location were not
supplied. This result does not close the remaining full-screen TUI, Unicode,
clipboard, lifecycle, performance, or original-host DNS/connection checks.
