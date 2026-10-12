![Weazl dial-up artwork in a classic sixteen-color terminal palette](docs/assets/we4zl-dialup_2.svg)

[we4zl-dialup_2.ans — terminal edition, UTF-8](docs/assets/we4zl-dialup_2.ans)

# Weazlterm: The G4 Is Still on the Wire

The corporate tech clerics wrote off the PowerPC a decade ago, but the G4 is still on the wire. Weazlterm is a native terminal packed with bundled modern SSH, custom-forged for Mac OS X 10.4.11 on PowerPC. Open the lid, reach your server, and get back to the gig.

Tiger's old SSH hits a `no hostkey alg` wall when trying to shake hands with a modern server. Weazlterm bypasses this entirely by bringing its own OpenSSH 10.6p1, compiled strictly for PowerPC and running locally on the Mac. This isn't some bloated translation layer or a relay box; it's original C99 and Objective-C hooking directly into the native AppKit chrome with the supplied Weazl icon.

**v0.1.1 is proven on the metal:** We have a verified interactive SSH connection from a 1.5 GHz PowerPC G4 with 1.25 GB RAM running Tiger, complete with working terminal colors. The first silent connection turned out to be a DNS issue; the machine itself had more to give.

## Get on the Wire

The Tiger binary is pre-compiled and lives in this repository. You do not need to burn cycles building it on your vintage Mac.

- [Download Weazlterm 0.1.1 for Tiger / PowerPC](release/weazlterm-0.1.1-tiger-ppc.zip)
- [SHA-256 checksum](release/weazlterm-0.1.1-tiger-ppc.zip.sha256)
- [Unpacked app bundle](release/weazlterm.app)

1. Extract the ZIP and copy the complete `weazlterm.app` to your Mac or a USB drive.
2. Open the app in Tiger.
3. Connect from the prompt: `ssh yourname@your-server`.

Verify the payload by running `ssh -V`; this build should report `OpenSSH_10.6p1`. For a new host, compare its fingerprint with a trusted server-side source before accepting the key.

The bundle packs the terminal, SSH helpers, the icon, startup resources, and OpenSSH notices. Zero Xcode, zero MacPorts, and no separate crypto-library installations are required on the target Mac. The app is relocatable; direct USB launches across filesystems remain a valid hardware acceptance check.

## The Deck

One window. A local shell. Your remote machine on the other end.

* **Native PPC:** 32-bit PowerPC Mach-O executables linked against Tiger's system libraries and frameworks.
* **Bundled SSH:** Ordinary `ssh` and `ssh-keygen` commands inside Weazlterm resolve directly to the app's internal helpers. A missing helper fails closed.
* **Terminal Color:** ANSI, 256-color, and true-color handling is in the core; color output was confirmed working in the reported G4 session.
* **Keyboard First:** Cursor/navigation keys, control keys, and Edit-menu pasting are active. Window resizing properly updates the PTY size.
* **Local Setup:** The app reads your shell startup files and establishes its SSH command routing afterward. It strictly leaves your dotfiles and Tiger's `/usr/bin/ssh` untouched.

SSH still respects your user configuration, keys, and known-hosts files. The server keeps its security settings. If you deliberately invoke `/usr/bin/ssh`, it will still run Tiger's ancient system client.

## Sysop Notes

If a connection sits quietly, get the last debug line before guessing:

```sh
ssh -vvv -o ConnectTimeout=15 yourname@your-server
```

A hostname that will not resolve needs a DNS fix or the correct server IP. The connection timeout does not bound every earlier step, including name resolution; the G4 test encountered this exactly with a `.local` hostname before connecting successfully to another destination.

Version 0.1.1 also patches a startup-path bug from the first build. Tiger's Bash 2.05b lacks `BASH_SOURCE`, so the app now explicitly supplies the resource path needed to locate its helpers. This fix was reproduced and tested with Bash 2.05b on the build host prior to the successful G4 session.

## Still on the Bench

This is an early terminal build with a working hardware-tested SSH path. The remaining work is visible:

* Scrollback and text selection/copy are currently unimplemented.
* `scp` and `sftp` are not packaged; their commands intentionally refuse to run.
* Unicode decoding exists, but wide and combining character layouts are incomplete.
* Full-screen programs such as `vim`, `less`, `top`, and `tmux` require broader hardware testing. `TERM=xterm-256color` is currently advertised.
* Paste, resize, job control, shutdown, and USB relocation still need remaining G4 acceptance tests. CPU, memory, and battery budgets are pending measurement.

The successful session is user-reported hardware evidence. A captured negotiation log and the complete interoperability test matrix remain work to do. See [docs/STATUS.md](docs/STATUS.md) for the exact boundaries.

## Under the Hood

Small modules. Original terminal code. Upstream cryptography.

The C core handles terminal state and parsing. Tiger-compatible Objective-C handles the native window, drawing, and input. PTY operations are event-driven—there is no recurring idle animation timer burning CPU. OpenSSH stays a separate, attributed dependency. Ghostty and Alacritty informed the design through their public architecture material, but no terminal source was copied.

No Electron, no cloud accounts, no telemetry, or background updaters. Work happens when the session has work to do. Efficiency claims wait for measurements.

The PowerPC build uses a prepared Linux cross-toolchain, the Mac OS X 10.4u SDK, a GCC Objective-C frontend, and pinned OpenSSH sources. `make app-ppc` builds the helpers and the app. `make ssh` builds only for the build machine, not automatically for PowerPC. Host tests establish host behavior; they do not substitute for the G4.

Build and hardware gates are in the [execution workbook](WORKBOOK.md). The binary retains its [OpenSSH license notices](release/weazlterm.app/Contents/Resources/licenses/OpenSSH-LICENCE.txt).

Weazl knows. Weazl is wise. Weazl will never tax the gig.
