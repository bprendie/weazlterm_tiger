Weazlterm 0.3.0

Native PowerPC terminal for Mac OS X 10.4.11, with OpenSSH portable 10.6p1.
This build adds selection/copy, 2,000 lines of shell scrollback, and large
clipboard pastes alongside SFTP, multiple windows, and native Tiger tabs.

Command-N: new terminal window
Command-T: new tab in the active window
Command-W: close the active tab (or its window when it is the last tab)
Command-Shift-W: close the active window and its sessions
Command-Shift-[ / ]: previous / next tab
Command-C: copy selected text
Command-A: select all retained text in this tab
Command-V: paste from the clipboard (up to 1 MiB)
Shift-Page Up / Down or mouse wheel: browse shell scrollback
Command-Q: quit all windows and sessions

Drag to select text. Double-click a word or triple-click a row. Shift-click
extends a selection. Right-click or Control-click opens the clipboard menu.
Automatically wrapped lines join when copied; actual newlines and indentation
are preserved. Copy includes selected scrollback, up to 2,000 saved rows.
Full-screen alternate-screen applications keep their own scrolling behavior.

Paste preserves UTF-8 and tabs, normalizes line endings, and strips C0 controls
other than tabs/newlines, plus DEL. Bracketed paste is used when enabled by
the receiving program; otherwise multiline paste asks before proceeding.
Input waits while a paste drains; Control-C cancels remaining queued text and
sends an interrupt, closing any active paste bracket first.

Each tab has its own local shell and PTY. Closing a tab ends that session.
After closing the last window, Command-N opens another terminal.

ssh user@server
sftp user@server

At the sftp prompt use ls, cd, lcd, put, get, and bye. SFTP uses the bundled
SSH transport. ssh, ssh-keygen, and sftp resolve to app helpers; a missing
helper refuses to fall back to the old system client. Deliberate /usr/bin/ssh
or SFTP -S overrides can select another client.

Compare a new server's host-key fingerprint with a trusted source before
accepting it. Host-key checking remains enabled. OpenSSH notices: licenses/.

Clipboard/scrollback, SFTP, and new window/tab controls await G4 runtime testing. The 0.1.1 SSH
session and terminal colors were confirmed by the user on the G4.
scp is not included. The live screen does not reflow on resize.
Wide/combining characters and full-screen TUIs need further work/testing.
