Weazlterm 0.2.0

Native PowerPC terminal for Mac OS X 10.4.11, with OpenSSH portable 10.6p1.
This build adds SFTP, multiple terminal windows, and native Tiger tabs.

Command-N: new terminal window
Command-T: new tab in the active window
Command-W: close the active tab (or its window when it is the last tab)
Command-Shift-W: close the active window and its sessions
Command-Shift-[ / ]: previous / next tab
Command-V: paste from the clipboard
Command-Q: quit all windows and sessions

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

SFTP and new window/tab controls await G4 runtime testing. The 0.1.1 SSH
session and terminal colors were confirmed by the user on the G4.
scp is not included. Scrollback and selection/copy are not implemented.
Wide/combining characters and full-screen TUIs need further work/testing.
