#!/bin/bash
set -euo pipefail
# Build LuaJIT 2.1 for Android ABIs using NDK cross-compilation.
#
# Requirements:
#   - ANDROID_NDK_HOME set (NDK 25+)
#   - gcc-multilib installed when building 32-bit ABIs
#   - LuaJIT source at ./luajit-src/ (commit d0e88930 recommended for vcpkg compat)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NDK="${ANDROID_NDK_HOME:-/home/dev/android-sdk/ndk/29.0.13599879}"
NDKBIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
LUAJIT_SRC="$SCRIPT_DIR/luajit-src"
INSTALL_BASE="$SCRIPT_DIR/android/app/libs"
REQUESTED_ABIS="${OTCLIENT_ANDROID_ABIS:-arm64-v8a,armeabi-v7a,x86_64,x86}"

if [ ! -d "$LUAJIT_SRC/src" ]; then
    echo "ERROR: LuaJIT source not found at $LUAJIT_SRC"
    echo "Run: git clone https://github.com/LuaJIT/LuaJIT.git $LUAJIT_SRC"
    exit 1
fi

IFS=',' read -r -a ABI_LIST <<< "$REQUESTED_ABIS"
needs_32bit=false
for ABI in "${ABI_LIST[@]}"; do
    ABI_TRIMMED="$(echo "$ABI" | xargs)"
    if [ "$ABI_TRIMMED" = "armeabi-v7a" ] || [ "$ABI_TRIMMED" = "x86" ]; then
        needs_32bit=true
        break
    fi
done

if [ "$needs_32bit" = true ]; then
    if ! gcc -m32 -x c -c /dev/null -o /dev/null 2>/dev/null; then
        echo "Installing gcc-multilib for 32-bit cross-compilation..."
        sudo apt-get install -y gcc-multilib g++-multilib
    fi
fi

build_luajit() {
    local ABI=$1 CROSS_PREFIX=$2 CC_PREFIX=$3 HOST_CC=$4

    echo "=== Building LuaJIT for $ABI ==="
    cd "$LUAJIT_SRC"
    make clean 2>/dev/null || true

    make -j"$(nproc)" amalg \
        HOST_CC="$HOST_CC" \
        CROSS="${NDKBIN}/${CROSS_PREFIX}" \
        STATIC_CC="${NDKBIN}/${CC_PREFIX}clang" \
        DYNAMIC_CC="${NDKBIN}/${CC_PREFIX}clang -fPIC" \
        TARGET_LD="${NDKBIN}/${CC_PREFIX}clang" \
        TARGET_AR="$NDKBIN/llvm-ar rcus" \
        TARGET_STRIP="$NDKBIN/llvm-strip" \
        TARGET_CFLAGS="-fPIC -DLUAJIT_UNWIND_EXTERNAL -fno-stack-protector" \
        BUILDMODE=static

    local LIB_DIR="$INSTALL_BASE/lib/$ABI"
    mkdir -p "$LIB_DIR"
    cp src/libluajit.a "$LIB_DIR/libluajit-5.1.a"
    echo "  -> $LIB_DIR/libluajit-5.1.a ($(du -h "$LIB_DIR/libluajit-5.1.a" | cut -f1))"
}

for ABI in "${ABI_LIST[@]}"; do
    ABI_TRIMMED="$(echo "$ABI" | xargs)"
    case "$ABI_TRIMMED" in
        arm64-v8a)
            build_luajit "arm64-v8a" "aarch64-linux-android-" "aarch64-linux-android21-" "gcc"
            ;;
        armeabi-v7a)
            build_luajit "armeabi-v7a" "arm-linux-androideabi-" "armv7a-linux-androideabi21-" "gcc -m32"
            ;;
        x86_64)
            build_luajit "x86_64" "x86_64-linux-android-" "x86_64-linux-android21-" "gcc"
            ;;
        x86)
            build_luajit "x86" "i686-linux-android-" "i686-linux-android21-" "gcc -m32"
            ;;
        *)
            echo "ERROR: Unsupported ABI '$ABI_TRIMMED'"
            exit 1
            ;;
    esac
done

echo ""
echo "=== Installing headers ==="
mkdir -p "$INSTALL_BASE/include/luajit"
cp "$LUAJIT_SRC/src/lua.h" "$LUAJIT_SRC/src/lualib.h" "$LUAJIT_SRC/src/lauxlib.h" \
   "$LUAJIT_SRC/src/luaconf.h" "$LUAJIT_SRC/src/luajit.h" \
   "$INSTALL_BASE/include/luajit/"

cat > "$INSTALL_BASE/include/luajit/lua.hpp" << 'LUAHPP'
// C++ wrapper for LuaJIT header files.

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luajit.h"
}
LUAHPP

echo ""
echo "=== Requested ABIs built successfully ==="
for ABI in "${ABI_LIST[@]}"; do
    ABI_TRIMMED="$(echo "$ABI" | xargs)"
    ls -lh "$INSTALL_BASE/lib/$ABI_TRIMMED/libluajit-5.1.a"
done
