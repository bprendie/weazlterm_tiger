#!/bin/sh
# Cross-build the pinned OpenSSH client for Tiger using the separate Linux PPC
# toolchain. This script never copies the result into a release bundle.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
toolchain="$root/build/ppc-tiger-xcompiler"
source_dir="$root/deps/openssh-10.6p1"
configure="$root/build/ssh-ppc/configure"
cc="$toolchain/bin/ppc-ld64-gcc"
as_real="$toolchain/bin/powerpc-apple-darwin8-as.real"
compat="$root/compat/tiger-ppc"

if [ ! -x "$cc" ] || [ ! -x "$as_real" ] || [ ! -f "$toolchain/sdk/MacOSX10.4u.sdk/System/Library/Frameworks/Cocoa.framework/Headers/Cocoa.h" ]; then
    echo 'Tiger PPC cross-toolchain or its assembler is missing.' >&2
    exit 1
fi
if [ ! -x "$source_dir/configure" ]; then
    echo 'Run scripts/build-ssh.sh --fetch-only first, then extract the verified OpenSSH archive.' >&2
    exit 1
fi
mkdir -p "$root/build/ssh-ppc"
cd "$root/build/ssh-ppc"
make clean >/dev/null 2>&1 || true
# ld64 accepts unresolved dylib imports, so Autoconf link probes alone can
# misclassify post-Tiger APIs. Pin those features to the Tiger fallbacks.
CPPFLAGS="-I$compat -DHAVE_SHA2_H=1" \
AR="$toolchain/bin/powerpc-apple-darwin8-ar" \
RANLIB="$toolchain/bin/powerpc-apple-darwin8-ranlib" \
ac_cv_func_getentropy=no ac_cv_func_getrandom=no \
ac_cv_func_explicit_bzero=no ac_cv_func_explicit_memset=no \
ac_cv_func_memset_s=no ac_cv_func_reallocarray=no \
ac_cv_func_recallocarray=no ac_cv_func_freezero=no \
ac_cv_func_getline=no ac_cv_func_strnlen=no \
ac_cv_func_strndup=no ac_cv_func_b64_ntop=no \
ac_cv_func___b64_ntop=no ac_cv_func_b64_pton=no \
ac_cv_func___b64_pton=no ac_cv_func_bcrypt_pbkdf=no \
ac_cv_func_arc4random_buf=no \
ac_cv_func_arc4random_uniform=no ac_cv_func_timingsafe_bcmp=no \
ac_cv_func_SHA256Update=no ac_cv_func_SHA384Update=no \
ac_cv_func_SHA512Update=no \
CC="$cc" CFLAGS="-O2 -mcpu=G3 -Wno-error=incompatible-pointer-types -ffile-prefix-map=$root=." \
LDFLAGS='-Wl,-undefined,error' LIBS='' \
    "$source_dir/configure" --build=x86_64-pc-linux-gnu \
    --host=powerpc-apple-darwin8 --prefix=/usr/local/weazlterm \
    --sysconfdir=/etc/weazlterm --without-openssl --without-zlib \
    --without-pam --without-kerberos5 --without-libedit \
    --without-security-key-builtin --disable-strip
make -j "${JOBS:-4}" \
    AR="$toolchain/bin/powerpc-apple-darwin8-ar" \
    RANLIB="$toolchain/bin/powerpc-apple-darwin8-ranlib" \
    ssh ssh-keygen
file ssh ssh-keygen
"$toolchain/bin/powerpc-apple-darwin8-otool" -L ssh
"$toolchain/bin/powerpc-apple-darwin8-otool" -L ssh-keygen
