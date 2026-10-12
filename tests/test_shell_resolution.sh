#!/bin/sh
set -eu
shell=${WEAZLTERM_TEST_BASH:-/bin/bash}
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rc=${WEAZLTERM_TEST_RC:-$root/resources/shell/weazlterm.bashrc}
tmp=${TMPDIR:-/tmp}/weazlterm-shell-test-$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home" "$tmp/helper tools"
bundle="$tmp/Weazlterm USB copy.app"
mkdir -p "$bundle/Contents/Helpers" "$bundle/Contents/Resources/shell"
cat > "$tmp/helper tools/ssh" <<'EOF'
#!/bin/sh
printf 'bundled:%s\n' "$*"
EOF
cat > "$tmp/helper tools/ssh-keygen" <<'EOF'
#!/bin/sh
printf 'bundled-keygen:%s\n' "$*"
EOF
chmod +x "$tmp/helper tools/ssh" "$tmp/helper tools/ssh-keygen"
cp "$tmp/helper tools/ssh" "$bundle/Contents/Helpers/ssh"
cp "$tmp/helper tools/ssh-keygen" "$bundle/Contents/Helpers/ssh-keygen"
cp "$root/resources/helpers/scp" "$bundle/Contents/Helpers/scp"
cp "$root/resources/helpers/sftp" "$bundle/Contents/Helpers/sftp"
chmod +x "$bundle/Contents/Helpers/scp" "$bundle/Contents/Helpers/sftp"
cp "$rc" "$bundle/Contents/Resources/shell/weazlterm.bashrc"
cat > "$tmp/home/.bash_profile" <<'EOF'
PATH=/usr/bin:/bin
export PATH
ssh() { printf '%s\n' system-profile-function; }
. "$HOME/.bashrc"
EOF
cat > "$tmp/home/.bashrc" <<'EOF'
PATH=/usr/bin:/bin
export PATH
ssh() { printf '%s\n' system-rc-function; }
alias ssh=/usr/bin/ssh
EOF
output=$(HOME="$tmp/home" WEAZLTERM_RC="$bundle/Contents/Resources/shell/weazlterm.bashrc" \
    "$shell" --noprofile --norc -c \
    '. "$HOME/.bash_profile"; . "$WEAZLTERM_RC"; type -a ssh >/dev/null; ssh host; ssh-keygen -V' \
    2>/dev/null)
case "$output" in
    *'bundled:host'*) ;;
    *) printf 'plain ssh did not run the bundled client:\n%s\n' "$output" >&2; exit 1;;
esac
case "$output" in
    *'bundled-keygen:-V'*) ;;
    *) printf 'ssh-keygen did not run the bundled helper:\n%s\n' "$output" >&2; exit 1;;
esac
case "$output" in
    *system-profile-function*|*system-rc-function*|*/usr/bin/ssh*)
        printf 'system ssh overrode the bundle:\n%s\n' "$output" >&2; exit 1;;
esac
printf '%s\n' 'shell: profile/rc PATH overrides, alias/function, command hash, spaced path passed'

output=$(HOME="$tmp/home" WEAZLTERM_RC="$bundle/Contents/Resources/shell/weazlterm.bashrc" \
    "$shell" --noprofile --rcfile "$bundle/Contents/Resources/shell/weazlterm.bashrc" \
    -i -c 'ssh interactive-host' 2>/dev/null)
case "$output" in
    *'bundled:interactive-host'*) ;;
    *) printf 'interactive rc startup did not run bundled SSH:\n%s\n' "$output" >&2; exit 1;;
esac
printf '%s\n' 'shell: interactive rc startup resolves bundled SSH'

output=$(HOME="$tmp/home" WEAZLTERM_RC="$bundle/Contents/Resources/shell/weazlterm.bashrc" \
    "$shell" --noprofile --norc -c \
    '. "$WEAZLTERM_RC"; command scp file host:/tmp/' 2>&1 || :)
case "$output" in
    *'does not include scp'*) ;;
    *) printf 'command scp escaped the unsupported-operation guard:\n%s\n' "$output" >&2; exit 1;;
esac
printf '%s\n' 'shell: command scp fails closed instead of reaching system scp'

rm "$bundle/Contents/Helpers/ssh"
output=$(HOME="$tmp/home" WEAZLTERM_RC="$bundle/Contents/Resources/shell/weazlterm.bashrc" \
    "$shell" --noprofile --norc -c \
    '. "$HOME/.bash_profile"; . "$WEAZLTERM_RC"; ssh host' 2>&1 || :)
case "$output" in
    *'refusing the system SSH fallback'*) ;;
    *) printf 'missing bundled SSH did not fail closed:\n%s\n' "$output" >&2; exit 1;;
esac
printf '%s\n' 'shell: missing bundled SSH fails closed'
