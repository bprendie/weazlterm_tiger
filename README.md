![Weazl dial-up artwork in a classic sixteen-color terminal palette](docs/assets/we4zl-dialup_2.svg)

[we4zl-dialup_2.ans — terminal edition, UTF-8](docs/assets/we4zl-dialup_2.ans)

# Weazlterm: The G4 Is Still on the Wire

The corporate tech clerics wrote off the PowerPC a decade ago, but the G4 is still on the wire. Weazlterm is a native terminal packed with bundled modern SSH, custom-forged for Mac OS X 10.4.11 on PowerPC. Open the lid, reach your server, and get back to the gig.

Tiger's old SSH hits a `no hostkey alg` wall when trying to shake hands with a modern server. Weazlterm bypasses this entirely by bringing its own OpenSSH 10.6p1, compiled strictly for PowerPC and running locally on the Mac. This isn't some bloated translation layer or a relay box; it's original C99 and Objective-C hooking directly into the native AppKit chrome with the supplied Weazl icon.

**v0.1.1 is proven on the metal:** We have a verified interactive SSH connection from a 1.5 GHz PowerPC G4 with 1.25 GB RAM running Tiger, complete with working terminal colors. The first silent connection turned out to be a DNS issue; the machine itself had more to give.

**Current build: v0.3.0** adds text selection, clipboard copy, 2,000 lines of
shell scrollback, and pastes up to 1 MiB. SFTP, terminal windows, and Tiger
tabs remain included. Host tests and PPC cross-build checks pass; the new
clipboard and window controls still need their G4 runtime test.

## Get on the Wire

The Tiger binary is pre-compiled and lives in this repository. You do not need to burn cycles building it on your vintage Mac.

- [Download Weazlterm 0.3.0 for Tiger / PowerPC](release/weazlterm-0.3.0-tiger-ppc.zip)
- [SHA-256 checksum](release/weazlterm-0.3.0-tiger-ppc.zip.sha256)
- [Unpacked app bundle](release/weazlterm.app)

1. Quit an older Weazlterm if it is running. Extract the ZIP and copy the complete `weazlterm.app` to your Mac or a USB drive, replacing the previous app.
2. Open the app in Tiger.
3. Connect from the prompt: `ssh yourname@your-server`, or `sftp yourname@your-server` for file transfers.

Verify the payload by running `ssh -V`; this build should report `OpenSSH_10.6p1`. For a new host, compare its fingerprint with a trusted server-side source before accepting the key.

The bundle packs the terminal, SSH helpers, the icon, startup resources, and OpenSSH notices. Zero Xcode, zero MacPorts, and no separate crypto-library installations are required on the target Mac. The app is relocatable; direct USB launches across filesystems remain a valid hardware acceptance check.

## The Deck

A shell per tab. A window per job. Your remote machine on the other end.

* **Native PPC:** 32-bit PowerPC Mach-O executables linked against Tiger's system libraries and frameworks.
* **Bundled SSH:** Ordinary `ssh`, `ssh-keygen`, and `sftp` commands inside Weazlterm resolve directly to the app's internal helpers. A missing helper fails closed.
* **Terminal Color:** ANSI, 256-color, and true-color handling is in the core; color output was confirmed working in the reported G4 session.
* **Keyboard First:** Cursor/navigation keys, control keys, and Edit-menu pasting are active. Window resizing properly updates the PTY size.
* **Local Setup:** The app reads your shell startup files and establishes its SSH command routing afterward. It strictly leaves your dotfiles and Tiger's `/usr/bin/ssh` untouched.

SSH still respects your user configuration, keys, and known-hosts files. The server keeps its security settings. If you deliberately invoke `/usr/bin/ssh`, it will still run Tiger's ancient system client.

## More Lines, More Sessions

| Shortcut | Action |
| --- | --- |
| Command-N | New terminal window |
| Command-T | New tab in the active window |
| Command-W | Close the active tab; close the window if it was the last tab |
| Command-Shift-W | Close the active window and all its sessions |
| Command-Shift-[ / ] | Previous / next tab |
| Command-C | Copy selected text |
| Command-A | Select all retained text in this tab |
| Command-V | Paste up to 1 MiB |
| Shift-Page Up / Down | Browse shell scrollback |
| Command-Q | Quit all sessions |

Each tab owns an independent shell and PTY. Closing a tab ends its session;
other tabs keep running. Close the final window and Command-N still opens a
fresh terminal. New terminals start a local shell, including when the first
session was launched using `--ssh`.

## Copy the Signal

Drag across the text you want, then **Command-C**. Double-click selects a
word; triple-click selects a row. Shift-click extends the selection. The
right-click menu (Control-click on a one-button mouse) has Copy, Paste, and
Select All too. **Control-C still interrupts the shell.**

Mouse-wheel scrolling and Shift-Page Up / Down reach the last **2,000 saved
shell rows**. Command-A includes retained history, so a long LLM answer can
leave the window and still reach your clipboard. Automatically wrapped lines
join back together when copied; actual newlines and indentation stay intact.
Copy writes plain Unicode text, without terminal color escapes.

**Command-V** accepts up to **1 MiB of UTF-8 text**. The paste is queued as a
whole and streamed to the PTY; it is never silently clipped to fit the old
64 KiB input buffer. Further typing is refused while that queue drains.
Control-C cancels the unsent portion and sends an interrupt after completing
any paste bracket. Bytes already delivered cannot be recalled.

Applications that enable bracketed paste receive its opening and closing
markers. With other applications, multiline paste asks first because newlines
can immediately run shell commands. Line endings are normalized; tabs and
UTF-8 survive. Escape and other C0 controls (apart from tabs/newlines), plus
DEL, are removed from pasted text.

History is bounded and belongs to each tab. Full-screen alternate-screen
applications manage their own scrolling; Select All there copies that screen.
Saved rows keep their original text after resizing, but the live screen does
not yet reflow and a narrower window clips wider historical rows on display.
Selecting a complete historical row still copies its full saved width.

## SFTP (Move the Payload)

```sh
sftp yourname@your-server
```

Use `ls` and `cd` remotely, `lcd` for your local folder, `put file` to upload,
`get file` to download, and `bye` to leave. Quote paths containing spaces.
The app bundles OpenSSH's native SFTP client and selects its adjacent SSH
helper as the transport, including when the app is moved or renamed.
An explicit SFTP `-S` option can deliberately override that transport.

Host checks transferred a 1 MiB binary payload through the SFTP protocol and
verified byte-for-byte upload/download equality. That local-pipe fixture
checks transfers and launcher routing; the PPC network transfer test is next.

## Sysop Notes

If a connection sits quietly, get the last debug line before guessing:

```sh
ssh -vvv -o ConnectTimeout=15 yourname@your-server
```

A hostname that will not resolve needs a DNS fix or the correct server IP. The connection timeout does not bound every earlier step, including name resolution; the G4 test encountered this exactly with a `.local` hostname before connecting successfully to another destination.

Version 0.1.1 also patches a startup-path bug from the first build. Tiger's Bash 2.05b lacks `BASH_SOURCE`, so the app now explicitly supplies the resource path needed to locate its helpers. This fix was reproduced and tested with Bash 2.05b on the build host prior to the successful G4 session.

## Still on the Bench

This is an early terminal build with a working hardware-tested SSH path. The remaining work is visible:

* Clipboard interaction and scrollback need their real-G4 acceptance test.
* `scp` is not packaged; its command intentionally refuses to run.
* Unicode decoding exists, but wide and combining character layouts are incomplete.
* Full-screen programs such as `vim`, `less`, `top`, and `tmux` require broader hardware testing. `TERM=xterm-256color` is currently advertised.
* SFTP transfers, new windows/tabs, resize, job control, shutdown, and USB relocation still need remaining G4 acceptance tests. CPU, memory, and battery budgets are pending measurement.

The successful session is user-reported hardware evidence. A captured negotiation log and the complete interoperability test matrix remain work to do. See [docs/STATUS.md](docs/STATUS.md) for the exact boundaries.

## Under the Hood

Small modules. Original terminal code. Upstream cryptography.

The C core handles terminal state and parsing. Tiger-compatible Objective-C handles the native window, drawing, and input. PTY operations are event-driven—there is no recurring idle animation timer burning CPU. OpenSSH stays a separate, attributed dependency. Ghostty and Alacritty informed the design through their public architecture material, but no terminal source was copied.

No Electron, no cloud accounts, no telemetry, or background updaters. Work happens when the session has work to do. Efficiency claims wait for measurements.

The PowerPC build uses a prepared Linux cross-toolchain, the Mac OS X 10.4u SDK, a GCC Objective-C frontend, and pinned OpenSSH sources. `make app-ppc` builds the helpers and the app. `make ssh` builds only for the build machine, not automatically for PowerPC. Host tests establish host behavior; they do not substitute for the G4.

Build and hardware gates are in the [execution workbook](WORKBOOK.md). The binary retains its [OpenSSH license notices](release/weazlterm.app/Contents/Resources/licenses/OpenSSH-LICENCE.txt).

Weazl knows. Weazl is wise. Weazl will never tax the gig.
