# Weazlterm execution workbook for Luna

Build a usable native terminal for Mac OS X 10.4.11 on a 1.5 GHz PowerPC G4
with 1.25 GB RAM. The final output is **`./release/weazlterm.app`**, copied to
USB and launched directly in Tiger. The defining feature is working modern
SSH: typing `ssh bobp@weazltunes.teralab.local` must use the bundled client and
reach an authenticated session. Rendering a terminal window is insufficient.

Luna implements the steps below. The reviewing model independently tests and
reviews the changes with the user, including tests on the real G4. A checked
implementation task is not a passed hardware acceptance gate.

## 1 Working rules and scope

Read `AGENTS.md`, `docs/STATUS.md`, and the current source before editing.
On the user's development machine, also read:

```text
/home/bobp/weazl_ethos.md
/home/bobp/weazl_skill.md
/home/bobp/weazl_ethos_lite.md
```

Apply these rules throughout:

- Keep the core in C99 and the frontend in Tiger-compatible Objective-C with
  manual memory management. Go is not the toolchain for this target.
- Keep original source modules below 300 lines. Separate parsing, screen
  storage, rendering, input, process management, and SSH packaging.
- Use native AppKit with a measured CPU renderer first. No SwiftUI, Metal,
  Core Text assumption, ARC, blocks, Electron, browser frontend, telemetry,
  account system, background updater, or custom cryptography.
- Idle means event-driven waiting. No recurring polling or animation timer
  while idle or hidden. Redraw only damaged visible content.
- Use bounded scrollback, input queues, parser state, and output batches.
- Preserve the supplied art. Use native Tiger window controls and a quiet
  dark terminal surface; do not turn the icon into decorative app chrome.
- Keep secrets out of logs, argv, environment, source, and release artifacts.
  Let OpenSSH prompt in the PTY and use its established key formats.
- Do not replace `/usr/bin/ssh`, edit shell startup files, install daemons,
  enable weak server algorithms, or bypass host-key verification.

Working interpretation of cleanroom: original terminal implementation from
protocol documentation, with separately attributed open-source SSH/crypto
dependencies. Only Ghostty/Alacritty public architecture and feature material
has been consulted, not their terminal implementation source. This is not a
claim of a formal legally audited clean-room process. If the user requires
that process, settle its provenance requirements before further implementation.

### Required first release

Local interactive shell, bundled modern SSH, functional full-screen remote
TUIs, bounded scrollback, selection/copy/paste, resize, readable UTF-8 with
correct cell widths, 256 colors and true color, supplied icon, safe shutdown,
and standalone USB operation. One window/session is sufficient initially.

Tabs, splits, GPU acceleration, ligatures, inline images, shell integration
decorations, session persistence, GUI key management, and FIDO integration
are later work. No unaudited feature may be advertised through terminfo.

## 2 Known starting point

The repository already contains a small prototype. Inspect and improve it;
do not assume it is production-ready or rewrite it without a concrete reason.

| Area | Starting evidence | Outstanding work |
| --- | --- | --- |
| Terminal core | C parser/screen/color tests pass on Linux, including sanitizer runs | Full terminal behavior and Unicode semantics |
| PTY | Linux input, resize, queue bounds, EOF and shutdown tests pass | Races, exec errors, job control, Tiger behavior |
| Cocoa frontend | Cross-compiled PowerPC Mach-O app bundle against the Tiger 10.4u SDK | Launch, API behavior, input, layout, lifecycle and performance on hardware |
| SSH | OpenSSH 10.6p1 `ssh` and `ssh-keygen` built as strict-linked PPC Mach-O | Execute and authenticate from Tiger |
| Real server | Modern host-key/cipher selection reached from Linux | Verified host identity, authentication and G4 execution |
| Icon | Supplied legacy ICNS extracted and referenced in plist/build recipe | Actual Finder and Dock rendering on Tiger |
| Packaging | Test candidate assembled at `release/weazlterm.app`; icon and OpenSSH license included | USB relocation, launch and full dependency checks on Tiger |

The separate `build/ssh/ssh` remains an **x86-64 Linux ELF executable** and is
not in the release bundle. The bundle uses `build/ssh-ppc/ssh`. Its PPC
architecture and strict link dependencies have been inspected, but neither a
deployment-target flag nor an Info.plist minimum-version string proves that
the app launches on Tiger.

### The specific SSH failure

`no hostkey alg` indicates failure to agree on a server host-key algorithm,
before user authentication. The server observed at the requested hostname
advertised `ssh-ed25519`, `ecdsa-sha2-nistp256`, `rsa-sha2-256`, and
`rsa-sha2-512`. The candidate selected `ssh-ed25519`,
`sntrup761x25519-sha512@openssh.com`, and
`chacha20-poly1305@openssh.com` from Linux.

The probe used strict checking with empty trust files and disabled login
methods. It intentionally ended at host-key verification, without login or
adding a trusted key. The observed identity is untrusted until independently
verified. Algorithm negotiation success is not proof of authentication,
server identity, Tiger support, or end-to-end functionality.

## 3 Execution and review cadence

For each step:

1. Read its prerequisites and inspect the relevant files.
2. Make the smallest complete change satisfying the step.
3. Run its meaningful tests on the specified platform.
4. Update `docs/STATUS.md` with files changed, exact commands, platform,
   results, failures, and the next action. Label evidence Linux, PPC build,
   emulated execution, or physical G4 explicitly.
5. Hand the changed files and evidence to the reviewing model at each gate.
   Record reviewer findings and fixes separately from implementation claims.

Use `not started`, `in progress`, `implemented awaiting review`,
`review passed`, and `blocked by <specific prerequisite>` as step states.
Do not claim a test passed when it was skipped. A toolchain block must name
the missing compiler/SDK or failing symbol and preserve its build log.
Continue independent work if useful, but do not progress through a failed
SSH gate by adding UI polish. Never manufacture a release folder as a stand-in
for a working binary.

## 4 Step 1 Reproduce the baseline

**Prerequisite:** the current checkout and supplied icon archive.

- [ ] Inventory source, local modifications, build tools, SDK availability,
  and access to the G4. Ask only for missing build/test prerequisites; do not
  infer credentials or a Tiger SDK from unrelated files.
- [ ] Run `make test` and `make sanitize` on Linux. Preserve complete logs.
- [ ] Record `file build/ssh/ssh`, its version and `-Q` algorithm output.
- [ ] Confirm the pinned OpenSSH archive hash and upstream release provenance.
- [ ] Keep generated host binaries separate from future target binaries.
- [ ] Record all baseline limitations; check that no release is advertised.

**Pass:** repeatable host tests and an accurate status record. Linux sanitizer
flags are not expected to work with Tiger's old compiler.

## 5 Step 2 Prove the target build toolchain

**Prerequisite:** Step 1. This precedes substantial UI work.

Choose the first usable route:

1. Native build on Tiger with an appropriate Xcode/GCC toolchain, preferably
   Xcode 2.5 for the initial compatibility baseline.
2. A documented Linux cross-toolchain producing PowerPC Mach-O against a
   legally available Tiger SDK, with the matching Apple linker/tool support
   and Objective-C runtime ABI.

Do not silently use a modern macOS SDK or a PowerPC Linux compiler. Do not
download arbitrary prebuilt SSH executables as a substitute for the source
build. If neither route exists, identify exactly what the user must provide.

- [ ] Build and execute a trivial C program on the actual G4.
- [ ] Build and execute a minimal AppKit window against the same SDK/runtime.
- [ ] Verify 32-bit big-endian PowerPC Mach-O, deployment target and linked
  libraries. Inspect imported symbols for post-Tiger APIs.
- [ ] Keep target builds in distinct directories such as
  `build/ppc-tiger/`; clear configure caches when the target changes.
- [ ] Document compiler version, SDK provenance, compiler/linker flags and
  one reproducible invocation. Avoid CPU instructions newer than the G4.
- [ ] Adapt warnings for older GCC: current `-Wpedantic` is a host flag, not
  an established GCC 4.0-compatible flag. Use supported equivalents.
- [ ] Make cross-configuration explicit rather than allowing configure to
  mistake a target binary for a runnable build-host program.

**Gate A:** reviewing model sees both programs running on Tiger, plus binary
and dependency evidence. Without this, target feasibility remains unproven.

## 6 Step 3 Build modern SSH for Tiger first

**Prerequisite:** Gate A, or a functioning cross-toolchain while hardware
execution awaits the user. Gate B cannot pass without actual Tiger execution.

Use the pinned source and checksum in `scripts/build-ssh.sh`, then the separate
Tiger/PPC configure and build in `scripts/build-ssh-ppc.sh`. The PPC client is
packaged into the test candidate; host execution remains distinct from target
execution.

- [x] Add separate fetch/verify, configure, build, and staging steps.
  Fetch on the modern machine when Tiger's downloader cannot negotiate TLS.
  Verify the archive again before extraction/build on the target.
- [x] Compile `ssh` and `ssh-keygen` for PPC/Tiger. Keep patches small, named,
  versioned and explained. Preserve dependency license notices.
- [x] Use upstream's built-in crypto path. The PPC binary contains algorithm
  code for Ed25519, Curve25519/hybrid KEX, ChaCha20-Poly1305 and AES-CTR.
  Run `ssh -Q` on Tiger; strings in the PPC binary do not prove runtime support.
- [x] Keep cryptographic implementations intact. Compatibility work belongs
  around platform APIs, build configuration and unsupported OS facilities.
- [ ] Verify secure OS entropy on Tiger and run upstream crypto/self-tests
  that apply to the chosen build. Never replace entropy with time/PID seeds.
- [x] Strict-link target binaries and inspect dynamic dependencies, including
  optional automatically detected libraries. The SSH helpers currently link
  only Tiger `libSystem`; confirm the same on the target system.
- [ ] If the chosen upstream cannot run on Tiger, diagnose the failing APIs
  first. Do not silently downgrade to an unsupported old OpenSSH release.
- [ ] Verify Ed25519 host-key negotiation, authentication, key generation,
  password/passphrase prompts, and any RSA-SHA2/ECDSA interoperability needed
  on the G4. Do not infer runtime support from a compiled algorithm list.

**Target checks:**

```sh
./ssh -V
./ssh -Q key
./ssh -Q kex
./ssh -Q cipher
./ssh-keygen -t ed25519 -f ./temporary-test-key
```

Use a temporary test directory. Do not overwrite the user's keys or retain
test private keys in artifacts. Verify key generation, signing and reading
encrypted private keys through the upstream and interoperability tests.

### Controlled interoperability fixture

- [ ] Add a reproducible local test server with a freshly generated Ed25519
  host key and a temporary test user/key. Keep it loopback-only and isolated.
- [ ] Trust the fixture key from its generated source file, not by disabling
  checking or blindly accepting a network scan.
- [ ] Authenticate using Ed25519; run a harmless fixed command and assert its
  output and exit status. Exercise both command and PTY sessions.
- [ ] Force Curve25519 plus ChaCha20-Poly1305; test AES-CTR plus a SHA-2 MAC
  separately. Exercise a supported hybrid KEX and record G4 handshake time.
- [ ] Reject an unknown key in strict mode and reject a changed host key.
- [ ] Test wrong credentials, password input without echo, passphrase prompts,
  interrupted connections, and reconnection. Do not log secret input.
- [ ] Destroy fixture processes/credentials after the test.

### Real server test from the G4

Independently confirm the server's host-key fingerprint with the user or a
trusted server-side path before accepting it. Do not change `sshd_config`.
Use the bundled client explicitly before introducing shell integration:

```sh
"/path/to/weazlterm.app/Contents/Helpers/ssh" -v bobp@weazltunes.teralab.local
```

**Gate B:** an authenticated interactive session from the G4, a modern host-key
algorithm and cipher in the negotiation log, and unchanged server security.
Record the client's build identity, OS/hardware, authentication method and
remote `uname -a`. Redact usernames/paths as needed when sharing externally.
Do not advance this gate based solely on `ssh -Q` or a Linux handshake.

## 7 Step 4 Ensure ordinary ssh uses the bundled client

**Prerequisite:** the verified helper. Design/tests can begin earlier.

`main.m` launches the system login Bash, then replaces it with an interactive
Bash using the app's own rc file. That file sources the user's `.bashrc`, then
clears `ssh`/`ssh-keygen` aliases and functions, resets command hashing, and
pins both commands to `Contents/Helpers`. `scp` and `sftp` fail closed.

- [x] Provide a managed startup path for Tiger's Bash that preserves useful
  user setup and establishes bundled SSH resolution after profile processing.
  Keep it inside the app; do not edit the user's dotfiles.
- [x] Handle aliases, shell functions, command hashing, and reset PATHs.
  Document how deliberate use of `/usr/bin/ssh` bypasses the bundle.
- [x] Make `ssh-keygen` resolve consistently. `scp` and `sftp` placeholders
  fail closed until those features are deliberately supported.
- [x] Resolve helper paths relative to the running bundle, never the current
  directory or a build-machine absolute path. Quote spaces and special chars.
- [x] Keep `--ssh` as a direct argv-based route to the bundled executable.
  Do not concatenate destinations into a shell command string.
- [x] Fail closed when the helper is missing. Never silently fall back to
  system SSH.
- [x] Show terminal/SSH diagnostics in the PTY and retain the child exit code
  or terminating signal in the window title after session shutdown.
- [x] Test profiles that override PATH, alias `ssh`, define
  an `ssh` function, or cache `/usr/bin/ssh`. Test a bundle path with spaces.
  These shell-resolution cases pass on the Linux host; Finder/Tiger behavior
  remains unverified.

**Gate C:** in an ordinary shell launched from Finder, `type -a ssh` and
`ssh -V` identify the bundled implementation, and the exact command
`ssh bobp@weazltunes.teralab.local` authenticates from Tiger. A working `--ssh`
shortcut alone does not satisfy this gate.

## 8 Step 5 Harden terminal and process correctness

**Prerequisite:** SSH feasibility established. Preserve the existing tests.

- [ ] Add terminal-state replies needed by real applications, DECSC/DECRC
  semantics, origin/insert modes, tab stops, line drawing, erase/edit behavior,
  scroll regions and alternate-screen behavior as exercised by fixtures.
- [ ] Fix Unicode cell layout: incremental UTF-8, invalid sequences, combining
  marks, double-width cells, continuation cells, fallback glyphs, erase and
  resize. The current decoder stores scalars but treats every scalar as one
  cell; it is not full Unicode terminal support.
- [ ] Bound escape strings and parameters without displaying ignored OSC/DCS
  payloads. Unsupported controls must not trigger clipboard, file or shell
  actions. Keep OSC 52 writes disabled unless explicitly designed and tested.
- [ ] Add bounded scrollback, default 2,000 lines, with a documented memory
  cap and a predictable resize policy. No unbounded output retention.
- [ ] Add meaningful fixtures covering application output, not tests that
  merely restate the implementation. Continue malformed/random-input tests
  with sanitizers on the modern host and endian checks on PPC.
- [ ] Audit PTY startup/exec errors, interrupted syscalls, short writes,
  closed pipes, child reaping, descendants, SIGWINCH, foreground job control,
  Ctrl-C, Ctrl-D, Ctrl-Z, `fg`, HUP and immediate window close.
- [ ] Resolve the current worker/main-thread lifecycle: synchronous output
  delivery provides backpressure but must never deadlock while closing.
  Never destroy a mutex/PTY while another thread uses it.
- [ ] Replace the current simplistic EOF/kill policy where necessary; report
  a real child exit status and distinguish startup failure from clean exit.
- [ ] Test blocked readers, output floods, repeated open/close and SSH session
  teardown. Check for leaked descriptors and orphaned child processes.
- [ ] Make queued paste atomic or safely streamed with bounds. Truncation or
  loss of a bracketed-paste terminator must never execute unintended input.

**Pass:** parser, PTY, lifecycle and malformed-input suites pass; real target
tests include job control and teardown. Record unsupported sequences rather
than declaring complete xterm compatibility.

## 9 Step 6 Complete the Tiger interface

**Prerequisite:** working target shell and core behavior.

- [ ] Compile every Objective-C module against Tiger's actual headers. Audit
  selectors, symbols and runtime features. Source that looks old is not proof.
- [ ] Use Monaco or an available native monospace fallback. Align each glyph
  with terminal cell positions; natural string advance alone is insufficient
  for wide/combining characters or fallback fonts.
- [ ] Implement selection, Cmd-C copy, Cmd-V paste, keyboard scrollback,
  page navigation and coherent resize. Preserve Ctrl-C for the foreground job.
- [ ] Implement common function/navigation keys and modifiers, including
  Option behavior. Test local Bash/readline and remote applications.
- [ ] Route non-ASCII text input through a Tiger-compatible text-input path;
  test accented text and composition instead of only `keyDown:` strings.
- [ ] Coalesce output and redraw only affected regions. Do not allocate
  per-character AppKit objects in the hot path without measurements.
- [ ] Continue essential PTY reads while minimized; stop invisible drawing.
  Cursor blink may be off by default. Do not add an idle heartbeat.
- [ ] Keep shell/SSH errors actionable. A closed session must not look live.

**Review:** `vim`, `less`, `top` and a persistent `tmux` session on the remote
host, with scrolling, colors, resize, copy/paste and reconnect. Record exact
versions and failures. These applications are tests, not bundled dependencies.

## 10 Step 7 Make terminal identification work remotely

The prototype uses `TERM=weazlterm` and ships a partial custom terminfo entry.
A remote host will not automatically have it. A successful SSH login with
broken `vim` or `tmux` is not the final product.

- [ ] Prefer a standard installed TERM such as `xterm-256color` only after the
  declared capabilities have been implemented and tested on Tiger and Linux.
- [ ] If retaining custom TERM, provide a documented one-time remote install
  and a usable fallback. Never silently upload files or execute setup remotely.
- [ ] Resolve the first-login path without requiring the user to debug an
  unknown-terminal failure. The final standard-TERM strategy is preferred for
  the stated copy-and-run experience.
- [ ] Use Tiger-readable terminfo serialization for local entries. A modern
  `tic` output is not automatically compatible with Tiger's ncurses.
- [ ] Test local Bash/readline and remote TUIs with the advertised TERM. Do
  not claim capabilities solely because a similarly named terminal has them.

**Gate D:** the normal SSH workflow reaches a usable full-screen terminal,
with no remote bootstrap required for the chosen release behavior.

## 11 Step 8 Package the supplied icon

The user supplied `WeazlTerm-Icons.zip`. Its
`WeazlTerm-Icons/WeazlTerm.icns` is already extracted to
`resources/WeazlTerm.icns` and referenced by `CFBundleIconFile` and `make app`.
The source PNG is `Tiger-Era Cyber Weasel Terminal.png`.

The ICNS contains legacy RGB/mask pairs at 16, 32, 48 and 128 pixels:
`is32/s8mk`, `il32/l8mk`, `ih32/h8mk`, `it32/t8mk`. Its SHA-256 is:

```text
b564e5f55842cd46e9f5d423935252f3ef81d198c962341ee300624d458ffe84
```

- [ ] Use the supplied ICNS directly; retain the original ZIP and provenance.
- [ ] Verify resource chunk sizes and alpha masks, then check Finder, Dock
  and application switching on Tiger at small and large sizes.
- [ ] Do not replace it with an asset catalog or a PNG-only modern ICNS.
- [ ] Keep icon conversion tools out of runtime requirements.

**Pass:** the supplied icon displays correctly on Tiger. The source archive's
own README explicitly says it has not yet been tested on a running Tiger.

## 12 Step 9 Build a relocatable release

**Prerequisite:** Gates B, C and D; target UI and icon checks complete.

Implement one documented release command, preferably `make release`, that
stages and verifies the complete app before placing it at the exact destination:

```text
release/
  weazlterm.app/
    Contents/
      Info.plist
      MacOS/
        weazlterm
      Helpers/
        ssh
        ssh-keygen
      Resources/
        WeazlTerm.icns
        terminfo/             if needed by the chosen TERM strategy
        shell/                managed shell startup resources
        licenses/             upstream notices for included components
      Frameworks/             only if verified private dylibs are needed
```

- [ ] Build into a staging directory. Reject absent/wrong-architecture
  helpers, missing resources, failed checks, or external dependency paths.
- [ ] Verify each executable and bundled library is PPC Mach-O with a Tiger
  ABI and G4-compatible instructions. A universal binary must include working
  32-bit PPC, not just Intel or modern ARM.
- [ ] Audit transitive dylibs. Use static third-party dependencies where
  practical; system AppKit/libSystem remain dynamic. Any private dylib must
  use Tiger-supported relative loading and work when launched by its helper.
  Do not assume modern `@rpath` support.
- [ ] Remove developer paths and reliance on `/opt/local`, `/usr/local`, a
  source tree, external crypto providers or globally installed terminfo.
- [ ] Ensure all runtime resources are bundle-relative. Store settings and
  SSH known_hosts/keys in the user's home with correct permissions, never
  beside the executable or inside the bundle.
- [ ] Preserve executable bits, bundle structure, plist correctness and
  third-party notices. Include dependency versions and source hashes in a
  companion build manifest without secrets.
- [ ] Test launch from Finder with a minimal inherited environment, an
  arbitrary working directory, a renamed parent directory and spaces.
- [ ] Keep the final basename exactly `weazlterm.app` despite older source
  paths or the icon archive's capitalization.
- [ ] Verify the final app, then publish it to `release/weazlterm.app`. Keep
  test logs/manifests beside it, outside the bundle where appropriate.

**Fail condition:** a shell script pretending to be the app, a Linux ELF
helper, an app without working SSH, or instructions requiring the target user
to install Xcode/MacPorts/OpenSSL before launch.

## 13 Step 10 Test the actual USB artifact

**Prerequisite:** the packaged artifact, not a development executable.

- [ ] Copy the complete `.app` to the user's USB format without flattening
  the directory. Verify executable permissions after transport.
- [ ] Launch from the USB itself on the specified G4 running 10.4.11.
- [ ] Test a volume/folder name containing spaces and a read-only app bundle.
  No installer, network download, sudo or global-library installation.
- [ ] If the USB filesystem/mount disallows execution, record the exact
  constraint and test a compatible executable volume. Do not claim direct
  USB support based on copying the app onto the internal disk instead.
- [ ] Confirm icon, local shell, bundled `ssh -V`, and command resolution.
- [ ] Run `ssh bobp@weazltunes.teralab.local`, complete host verification and
  authentication normally, then exercise `vim`, `less`, `top`, and `tmux`.
- [ ] Test password/passphrase prompts, resize during output, paste, session
  exit, server disconnect, close/reopen, and sleep/wake if relevant.
- [ ] Verify unchanged host-key checks and rejection of a changed test key.
- [ ] Quit and check for remaining Weazlterm-owned processes, open sessions,
  repeated writes or background network activity.

### Initial performance targets

These are proposed acceptance targets, not measured claims. Measure on the
G4; report exceptions instead of tuning the numbers after seeing results.

| State | Target and measurement |
| --- | --- |
| Closed | No Weazlterm-owned recurring work or helper processes |
| Visible idle | No app-owned recurring timer; under 1% of one core averaged over 60 seconds |
| Hidden idle | No redraw/animation work; essential I/O remains event-driven |
| Local session memory | At most 64 MiB process RSS after bounded scrollback fills |
| One SSH session | At most 128 MiB combined app/helper RSS under the recorded test workload |
| Launch | Prompt within 3 seconds after warm launch; report cold/USB launch separately |
| Interaction | Local input visibly responsive during sustained output; record latency and workload |

Use tools actually available on Tiger. Record OS, CPU, RAM, display dimensions,
scrollback size, test duration and process CPU/RSS measurements. Include a
repeatable output workload and compare idle with/without Weazlterm. No battery
runtime or energy claims without the controlled measurements in the ethos.

**Gate E:** the reviewing model and user validate the USB-run app on the actual
G4. Until then, label it a release candidate, not a verified Tiger release.

## 14 Final review checklist

- [ ] `release/weazlterm.app` exists with the exact name and all resources.
- [ ] No Linux binaries, missing dependencies, SDK-only symbols or build paths.
- [ ] Modern SSH negotiates, verifies identity and authenticates on the G4.
- [ ] Plain `ssh bobp@weazltunes.teralab.local` invokes bundled SSH.
- [ ] Server security and Tiger's system SSH remain unchanged.
- [ ] Full-screen terminal, Unicode, paste, resize and shutdown tests pass.
- [ ] Supplied icon displays in Tiger Finder and Dock.
- [ ] Direct USB execution and bundle relocation pass.
- [ ] Measurements, remaining limitations, dependency notices and build
  reproduction instructions accompany the artifact.
- [ ] `docs/STATUS.md` records reviewer results and final artifact digest.

## 15 Reference material

Use protocol and platform documentation for original terminal work. Keep
upstream SSH modifications attributable and separate from terminal code.

- [Ghostty overview](https://ghostty.org/docs/about): native integration and
  separation of terminal core from frontend.
- [Alacritty overview](https://github.com/alacritty/alacritty): focused terminal
  scope and configurable behavior; its current graphics/toolchain requirements
  are not the target platform for Weazlterm.
- [Xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html):
  terminal behavior reference, interpreted against specific tests/capabilities.
- [OpenSSH portable](https://www.openssh.org/portable.html) and
  [release notes](https://www.openssh.org/releasenotes.html): verified dependency
  provenance and compatibility/security changes.
- [OpenSSH build prerequisites](https://github.com/openssh/openssh-portable/blob/master/INSTALL):
  compiler and optional crypto dependencies; a supported configuration does
  not establish Tiger compatibility.
- [SSH configuration manual](https://man.openbsd.org/ssh_config): host-key,
  authentication, algorithm and trust behavior.
- [Apple attributed string drawing](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AttributedStrings/Tasks/DrawingAttrStrings.html):
  initial AppKit drawing reference; validate target API availability against
  the real Tiger SDK and measure hot-path cost.


## 16 Version 0.2.0 scope extension (2026-10-12)

The user requested bundled SFTP, Command-N for new terminal windows, and
Command-T for tabs. This authorizes bringing these features forward from
later work. Every tab owns a separate WeazlView and WTSession; the app uses
Tiger NSTabView and keeps Command-N available after the last window closes.

Implementation/review evidence is in docs/STATUS.md. Hardware gate:

- [ ] Open two windows and several tabs via keyboard and Shell menu.
- [ ] Verify input/paste goes only to the selected tab and switching restores focus.
- [ ] Run separate commands in each tab; resize, switch during output, then close
  one tab/window. Other sessions must remain alive with their content intact.
- [ ] Run `exit` in a background tab; its ended label must not rename the active session.
- [ ] Close the last window, reopen using Command-N, then quit with Command-Q;
  check for leftover shell/SSH/SFTP processes.
- [ ] `sftp user@server`: verify host identity, authenticate, put/get a test file
  (including spaces and binary content), compare checksums, and exit with `bye`.
- [ ] Repeat SFTP after USB relocation with spaces; confirm the bundled SSH is used.

The 0.1.1 authenticated SSH/color report remains valid evidence for that build.
It is not a runtime pass for 0.2.0 window controls or SFTP.
