# Weazlterm engineering instructions

Read `WORKBOOK.md` and `docs/STATUS.md` before changing code. The workbook is
the execution contract; the status file distinguishes evidence from plans.

Target: Mac OS X 10.4.11, 32-bit big-endian PowerPC G4, 1.5 GHz, 1.25 GB RAM.
The final deliverable must be exactly `release/weazlterm.app`, relocatable and
launchable from USB. A Linux executable or an incomplete app is not a release.

The primary acceptance test is typing `ssh bobp@weazltunes.teralab.local` in
Weazlterm on the G4 and obtaining a working authenticated session using bundled
modern SSH. Never substitute Tiger's system SSH or weaken the server to pass.

Apply the user's `/home/bobp/weazl_ethos.md`, `weazl_skill.md`, and
`weazl_ethos_lite.md` when available. Relevant rules are captured in the
workbook for portability. Use C99 and Tiger-compatible Objective-C for this
target. Keep original source modules below 300 lines, excluding third-party
source. Use event-driven I/O, bounded queues, and no recurring idle timers.

Implement one workbook step at a time. Record commands, platform, actual
results, changed files, and remaining failures in `docs/STATUS.md`. Do not
claim Tiger compatibility from Linux tests. Luna implements; the reviewing
model independently checks the evidence and tests. Do not launch another
agent or model merely because this document names these roles.

Keep original terminal code separate from vetted OpenSSH dependencies.
Ghostty and Alacritty are design references, not source donors. Do not write
cryptography, disable host-key verification, add telemetry, or modify the
user's shell profiles/system SSH as an installation step.
