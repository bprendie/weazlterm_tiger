#!/bin/sh
# Build a Tiger/PowerPC application bundle with the local GCC/ld64 pipeline.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
toolchain="$root/build/ppc-tiger-xcompiler"
cc="$toolchain/bin/ppc-ld64-gcc"
cc1obj="$root/build/gcc-objc/gcc/cc1obj"
sdk="$toolchain/sdk/MacOSX10.4u.sdk"
gccinc="$toolchain/include/gcc"
fixexc="$toolchain/scripts/fix_exc_ld64.py"
fixup="$toolchain/scripts/ppc-darwin-fixup.py"
as="$toolchain/bin/powerpc-apple-darwin8-as"
otool="$toolchain/bin/powerpc-apple-darwin8-otool"
stage="$root/build/release-stage-$$/weazlterm.app"
objects="$root/build/ppc-app-objects"

for path in "$cc" "$cc1obj" "$as" "$root/build/ssh-ppc/ssh" \
    "$root/build/ssh-ppc/ssh-keygen" "$sdk/System/Library/Frameworks/Cocoa.framework/Headers/Cocoa.h"; do
    if [ ! -e "$path" ]; then
        echo "Required Tiger PPC build input is missing: $path" >&2
        exit 1
    fi
done
if [ -e "$root/release/weazlterm.app" ]; then
    echo 'release/weazlterm.app already exists; preserving it.' >&2
    exit 1
fi

mkdir -p "$objects" "$stage/Contents/MacOS" \
    "$stage/Contents/Resources/shell" "$stage/Contents/Resources/licenses" \
    "$stage/Contents/Helpers"

for name in screen parser csi color session session_io; do
    "$cc" -O2 -mcpu=G3 -Isrc -c "$root/src/$name.c" \
        -o "$objects/$name.o"
done

compile_objc() {
    source=$1
    name=$(basename "$source" .m)
    raw="$objects/$name.raw.s"
    fixed="$objects/$name.fixed.s"
    final="$objects/$name.s"
    "$cc1obj" -quiet -fnext-runtime -fobjc-abi-version=0 \
        -fconstant-string-class=NSConstantString -fexceptions -fPIC \
        -mcpu=G3 -O2 -Isrc -isystem "$gccinc" \
        -isystem "$toolchain/include" -isystem "$sdk/usr/include" \
        "$root/src/$source" -o "$raw"
    python3 "$fixexc" "$raw" "$fixed"
    python3 "$fixup" "$fixed" "$final"
    "$as" -arch ppc -force_cpusubtype_ALL -o "$objects/$name.o" "$final"
}

for source in main.m WeazlView.m WeazlDrawing.m WeazlInput.m; do
    compile_objc "$source"
done

set -- "$objects"/*.o
"$cc" "$@" -Wl,-undefined,error -framework Cocoa -lobjc \
    -o "$stage/Contents/MacOS/weazlterm"
cp "$root/resources/Info.plist" "$stage/Contents/Info.plist"
printf 'APPLWZLT' > "$stage/Contents/PkgInfo"
cp "$root/resources/README.txt" "$stage/Contents/Resources/README.txt"
cp "$root/deps/openssh-10.6p1/LICENCE" \
    "$stage/Contents/Resources/licenses/OpenSSH-LICENCE.txt"
cp "$root/resources/WeazlTerm.icns" "$stage/Contents/Resources/WeazlTerm.icns"
cp "$root/resources/shell/weazlterm.bashrc" "$stage/Contents/Resources/shell/weazlterm.bashrc"
cp "$root/build/ssh-ppc/ssh" "$stage/Contents/Helpers/ssh"
cp "$root/build/ssh-ppc/ssh-keygen" "$stage/Contents/Helpers/ssh-keygen"
cp "$root/resources/helpers/scp" "$stage/Contents/Helpers/scp"
cp "$root/resources/helpers/sftp" "$stage/Contents/Helpers/sftp"
chmod 755 "$stage/Contents/MacOS/weazlterm" \
    "$stage/Contents/Helpers/ssh" "$stage/Contents/Helpers/ssh-keygen" \
    "$stage/Contents/Helpers/scp" "$stage/Contents/Helpers/sftp"

"$otool" -hv "$stage/Contents/MacOS/weazlterm"
"$otool" -L "$stage/Contents/MacOS/weazlterm"
"$otool" -L "$stage/Contents/Helpers/ssh"
"$otool" -L "$stage/Contents/Helpers/ssh-keygen"

mkdir -p "$root/release"
mv "$stage" "$root/release/weazlterm.app"
echo "Built $root/release/weazlterm.app"
