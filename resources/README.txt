Weazlterm 0.1.0

Weazlterm is a PowerPC terminal preview for Mac OS X 10.4.11. Open the app
and enter an SSH command at the prompt. The bundled OpenSSH client is used for
ssh and ssh-keygen; the older system SSH is not used as a fallback.
The helper is OpenSSH portable 10.6p1; its license is in licenses/.
To deliberately use Tiger's client instead, invoke /usr/bin/ssh explicitly.

On the first connection, compare the server host-key fingerprint with a
trusted source before accepting it. Host-key checking remains enabled.

The first build is focused on interactive SSH shells. scp and sftp are not
included. Terminal support is an early xterm-compatible subset; it does not
yet provide scrollback or text selection/copy. Paste is available from the
Edit menu.
