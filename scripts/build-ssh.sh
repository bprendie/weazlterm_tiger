#!/bin/sh
# Bootstrap on a modern host, or build an already downloaded archive on Tiger.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=10.6p1
digest=a9dc9565dffe8640f64d863cd29a32bc4a3dbdec0566a7fc44c5d6ee767d5f39
archive="$root/deps/openssh-$version.tar.gz"
mkdir -p "$root/deps" "$root/build/ssh"
if [ ! -f "$archive" ]; then
    curl --fail --location --proto '=https' --tlsv1.2 \
        "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-$version.tar.gz" \
        -o "$archive.part"
    mv "$archive.part" "$archive"
fi
if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$archive" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$archive" | awk '{print $1}')
else
    actual=$(openssl dgst -sha256 "$archive" | awk '{print $NF}')
fi
if [ "$actual" != "$digest" ]; then
    echo 'OpenSSH archive checksum mismatch; refusing to build.' >&2
    exit 1
fi
if [ "${1:-}" = --fetch-only ]; then
    echo "Verified $archive"
    exit 0
fi
source_dir="$root/deps/openssh-$version"
if [ ! -d "$source_dir" ]; then
    tar -xzf "$archive" -C "$root/deps"
fi
cd "$root/build/ssh"
"$source_dir/configure" --prefix=/usr/local/weazlterm \
    --sysconfdir=/etc/weazlterm --without-openssl --without-zlib \
    --without-pam --without-kerberos5 --without-libedit \
    --without-security-key-builtin --disable-strip
make -j "${JOBS:-2}" ssh ssh-keygen
echo "Built $root/build/ssh/ssh and ssh-keygen (for the build host, unless cross-configured)."
