# Sourced only by the interactive shell created inside Weazlterm.
# main.m supplies this absolute resource path from NSBundle. Tiger's Bash
# 2.05b has no BASH_SOURCE; using it incorrectly resolves helpers as /Helpers.
_WEAZLTERM_CONTENTS=${WEAZLTERM_RC%/Resources/shell/weazlterm.bashrc}
_WEAZLTERM_HELPERS="$_WEAZLTERM_CONTENTS/Helpers"
if [ -n "${HOME:-}" ] && [ -r "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# A personal .bashrc may change PATH, cache Tiger's old ssh, or define an
# alias/function with the same name. Make app commands resolve to our helpers.
unalias ssh ssh-keygen scp sftp 2>/dev/null || :
unset -f ssh ssh-keygen scp sftp 2>/dev/null || :
PATH="$_WEAZLTERM_HELPERS:$PATH"
export PATH
hash -r
if [ -x "$_WEAZLTERM_HELPERS/ssh" ]; then
    hash -p "$_WEAZLTERM_HELPERS/ssh" ssh
else
    ssh() { printf '%s\n' 'Weazlterm bundled SSH is missing; refusing the system SSH fallback.' >&2; return 126; }
fi
if [ -x "$_WEAZLTERM_HELPERS/ssh-keygen" ]; then
    hash -p "$_WEAZLTERM_HELPERS/ssh-keygen" ssh-keygen
else
    ssh-keygen() { printf '%s\n' 'Weazlterm bundled ssh-keygen is missing.' >&2; return 126; }
fi
scp() { printf '%s\n' 'Weazlterm scp is not packaged in this build.' >&2; return 126; }
sftp() { printf '%s\n' 'Weazlterm sftp is not packaged in this build.' >&2; return 126; }
unset _WEAZLTERM_CONTENTS _WEAZLTERM_HELPERS
