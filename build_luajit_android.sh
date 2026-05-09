#!/bin/bash
set -euo pipefail
# Build LuaJIT 2.1 for all Android ABIs using NDK cross-compilation
# Based on official LuaJIT docs (luajit.org/install.html) and vcpkg build flags
#
# Requirements:
#   - ANDROID_NDK_HOME set (NDK 25+)
#   - gcc-multilib installed (for 32-bit targets: sudo apt install gcc-multilib)
#   - LuaJIT source at ./luajit-src/ (commit d0e88930 recommended for vcpkg compat)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NDK="${ANDROID_NDK_HOME:-/home/dev/android-sdk/ndk/29.0.13599879}"
NDKBIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
LUAJIT_SRC="$SCRIPT_DIR/luajit-src"
INSTALL_BASE="$SCRIPT_DIR/android/app/libs"

if [ ! -d "$LUAJIT_SRC/src" ]; then
    echo "ERROR: LuaJIT source not found at $LUAJIT_SRC"
    echo "Run: git clone https://github.com/LuaJIT/LuaJIT.git $LUAJIT_SRC"
    exit 1
fi

# Verify gcc -m32 works (needed for 32-bit targets)
if ! gcc -m32 -x c -c /dev/null -o /dev/null 2>/dev/null; then
    echo "Installing gcc-multilib for 32-bit cross-compilation..."
    sudo apt-get install -y gcc-multilib g++-multilib
fi

build_luajit() {
    local ABI=$1 CROSS_PREFIX=$2 CC_PREFIX=$3 HOST_CC=$4

    echo "=== Building LuaJIT for $ABI ==="
    cd "$LUAJIT_SRC"
    make clean 2>/dev/null || true

    # Official LuaJIT cross-compilation approach:
    # - HOST_CC="gcc -m32" for 32-bit targets (correct struct offsets in buildvm)
    # - CROSS= for NDK toolchain prefix
    # - STATIC_CC/DYNAMIC_CC for clang compiler
    # - TARGET_CFLAGS with -DLUAJIT_UNWIND_EXTERNAL (required for Android NDK C++ interop)
    # - Never use TARGET_SYS=Android (causes crashes, LuaJIT Issue #440)
    # - Use 'amalg' target for optimized single-file compilation
    make -j$(nproc) amalg \
        HOST_CC="$HOST_CC" \
        CROSS="${NDKBIN}/${CROSS_PREFIX}" \
        STATIC_CC="${NDKBIN}/${CC_PREFIX}clang" \
        DYNAMIC_CC="${NDKBIN}/${CC_PREFIX}clang -fPIC" \
        TARGET_LD="${NDKBIN}/${CC_PREFIX}clang" \
        TARGET_AR="$NDKBIN/llvm-ar rcus" \
        TARGET_STRIP="$NDKBIN/llvm-strip" \
        TARGET_CFLAGS="-fPIC -DLUAJIT_UNWIND_EXTERNAL -fno-stack-protector" \
        BUILDMODE=static

    # Install lib
    local LIB_DIR="$INSTALL_BASE/lib/$ABI"
    mkdir -p "$LIB_DIR"
    cp src/libluajit.a "$LIB_DIR/libluajit-5.1.a"
    echo "  -> $LIB_DIR/libluajit-5.1.a ($(du -h "$LIB_DIR/libluajit-5.1.a" | cut -f1))"
}

# arm64-v8a: 64-bit ARM (most modern Android devices)
build_luajit "arm64-v8a" "aarch64-linux-android-" "aarch64-linux-android21-" "gcc"

# armeabi-v7a: 32-bit ARM (older devices) — requires HOST_CC="gcc -m32"
build_luajit "armeabi-v7a" "arm-linux-androideabi-" "armv7a-linux-androideabi21-" "gcc -m32"

# x86_64: 64-bit x86 (emulators, Chromebooks)
build_luajit "x86_64" "x86_64-linux-android-" "x86_64-linux-android21-" "gcc"

# x86: 32-bit x86 (older emulators) — requires HOST_CC="gcc -m32"
build_luajit "x86" "i686-linux-android-" "i686-linux-android21-" "gcc -m32"

# Install headers (shared across all ABIs)
echo ""
echo "=== Installing headers ==="
mkdir -p "$INSTALL_BASE/include/luajit"
cp "$LUAJIT_SRC/src/lua.h" "$LUAJIT_SRC/src/lualib.h" "$LUAJIT_SRC/src/lauxlib.h" \
   "$LUAJIT_SRC/src/luaconf.h" "$LUAJIT_SRC/src/luajit.h" \
   "$INSTALL_BASE/include/luajit/"

# Create lua.hpp C++ wrapper
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
echo "=== All ABIs built successfully ==="
ls -lh "$INSTALL_BASE/lib/"*/libluajit-5.1.a
