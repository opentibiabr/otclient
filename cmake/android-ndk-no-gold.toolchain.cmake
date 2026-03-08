#
# android-ndk-no-gold.toolchain.cmake
#
# Wrapper around the Android NDK toolchain that removes the -fuse-ld=gold flag
# which is not available on all NDK builds (e.g., macOS)
#

# Unified Android toolchain wrapper for macOS that also handles vcpkg.
#
# This file is used as the *primary* CMake toolchain on Android builds. It
# performs three duties:
#   1. Validate environment (ANDROID_NDK_HOME, VCPKG_ROOT)
#   2. Configure vcpkg for the correct Android triplet and chainload the
#      official NDK toolchain.
#   3. Strip any stray "-fuse-ld=gold" flags that the upstream toolchains add.
#
# Resolve NDK path: prefer ANDROID_NDK_HOME env var, fall back to cmake variables
if(DEFINED ENV{ANDROID_NDK_HOME})
    set(_ANDROID_NDK_PATH "$ENV{ANDROID_NDK_HOME}")
elseif(DEFINED ANDROID_NDK AND EXISTS "${ANDROID_NDK}")
    set(_ANDROID_NDK_PATH "${ANDROID_NDK}")
elseif(DEFINED CMAKE_ANDROID_NDK AND EXISTS "${CMAKE_ANDROID_NDK}")
    set(_ANDROID_NDK_PATH "${CMAKE_ANDROID_NDK}")
else()
    message(FATAL_ERROR "ANDROID_NDK_HOME must be defined (or pass -DANDROID_NDK=) for Android builds")
endif()
set(ENV{ANDROID_NDK_HOME} "${_ANDROID_NDK_PATH}")

if(NOT DEFINED ENV{VCPKG_ROOT})
    message(FATAL_ERROR "VCPKG_ROOT must be defined for Android builds")
endif()

# Set up vcpkg triplet based on the chosen ANDROID_ABI value
if(ANDROID_ABI MATCHES "arm64-v8a")
    set(VCPKG_TARGET_TRIPLET "arm64-android" CACHE STRING "" FORCE)
elseif(ANDROID_ABI MATCHES "armeabi-v7a")
    set(VCPKG_TARGET_TRIPLET "arm-neon-android" CACHE STRING "" FORCE)
elseif(ANDROID_ABI MATCHES "x86_64")
    set(VCPKG_TARGET_TRIPLET "x64-android" CACHE STRING "" FORCE)
elseif(ANDROID_ABI MATCHES "x86")
    set(VCPKG_TARGET_TRIPLET "x86-android" CACHE STRING "" FORCE)
else()
    message(FATAL_ERROR "Please specify ANDROID_ABI (e.g. arm64-v8a)")
endif()
message(STATUS "vcpkg Android triplet: ${VCPKG_TARGET_TRIPLET}")

# Instruct vcpkg to chainload the real Android NDK toolchain
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE ${_ANDROID_NDK_PATH}/build/cmake/android.toolchain.cmake)

# Mark that we're using the custom wrapper so that CMakeLists can avoid
# re-applying its own Android logic
set(CUSTOM_ANDROID_TOOLCHAIN ON CACHE INTERNAL "Using our unified Android toolchain wrapper")

# Include the vcpkg helper script (will in turn load the chainloaded NDK toolchain)
include($ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake)

# After vcpkg and the NDK toolchain have run, scrub unsupported gold flags
foreach(flag_var CMAKE_CXX_FLAGS CMAKE_C_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS
                   CMAKE_CXX_FLAGS_DEBUG CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE CMAKE_C_FLAGS_RELEASE
                   CMAKE_CXX_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_C_FLAGS_MINSIZEREL
                   CMAKE_CXX_FLAGS_INIT CMAKE_C_FLAGS_INIT CMAKE_EXE_LINKER_FLAGS_INIT CMAKE_SHARED_LINKER_FLAGS_INIT CMAKE_MODULE_LINKER_FLAGS_INIT)
    if(DEFINED ${flag_var})
        string(REPLACE "-fuse-ld=gold" "-fuse-ld=lld" ${flag_var} "${${flag_var}}")
        message(STATUS "Processed ${flag_var}: ${${flag_var}}")
    endif()
endforeach()

message(STATUS "Unified Android toolchain initialized (gold linker removed)")
