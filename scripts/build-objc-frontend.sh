#!/bin/sh
# Build GCC's NeXT-runtime Objective-C front end for the Tiger PPC target.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_dir="$root/deps/toolchain/gcc-15.2.0"
build_dir="$root/build/gcc-objc"
sdk="$root/build/ppc-tiger-xcompiler/sdk/MacOSX10.4u.sdk"

if [ ! -x "$source_dir/configure" ] || [ ! -d "$sdk/usr/include/objc" ]; then
    echo 'Verified GCC 15.2 source and Tiger PPC SDK are required.' >&2
    exit 1
fi
mkdir -p "$build_dir"
cd "$build_dir"
CXXFLAGS='-g -O2 -std=c++11' \
CXXFLAGS_FOR_BUILD='-g -O2 -std=c++11' \
    "$source_dir/configure" --build=x86_64-pc-linux-gnu \
    --host=x86_64-pc-linux-gnu --target=powerpc-apple-darwin8 \
    --enable-languages=objc --disable-bootstrap --disable-multilib \
    --disable-nls --disable-libsanitizer --disable-libssp --disable-lto \
    --without-headers --with-sysroot="$sdk" \
    --with-gmp=/usr --with-mpfr=/usr --with-mpc=/usr --with-isl=/usr
make -j "${JOBS:-4}" all-gcc CXXFLAGS='-g -O2 -std=c++11'
test -x gcc/cc1obj
file gcc/cc1obj
echo 'Built GCC Objective-C compiler for powerpc-apple-darwin8.'
