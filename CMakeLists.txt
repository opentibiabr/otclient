cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

# CMAKE
# apt install build-essential git
# git clone https://github.com/Kitware/CMake/; cd CMake
# ./bootstrap && make && sudo make install

# VCPKG
# cmake -DCMAKE_TOOLCHAIN_FILE=/opt/workspace/vcpkg/scripts/buildsystems/vcpkg.cmake ..
# .\vcpkg --triplet x64-windows asio luajit glew physfs openal-soft libogg libvorbis zlib opengl nlohmann-json protobuf liblzma openssl
if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
	set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

if(DEFINED ENV{VCPKG_DEFAULT_TRIPLET} AND NOT DEFINED VCPKG_TARGET_TRIPLET)
	set(VCPKG_TARGET_TRIPLET "$ENV{VCPKG_DEFAULT_TRIPLET}" CACHE STRING "")
endif()

set(VCPKG_FEATURE_FLAGS "versions")
set(VCPKG_BUILD_TYPE "release")

if (VCPKG_TARGET_ANDROID)
    include("cmake/vcpkg_android.cmake")
	set(Android_INCLUDES ${Android_INCLUDES} ${CMAKE_SOURCE_DIR}/android/app/libs/include)
	set(Android_LIBRARIES ${Android_LIBRARIES} ${CMAKE_SOURCE_DIR}/android/app/libs/lib/${CMAKE_ANDROID_ARCH_ABI})
	include_directories(Android_INCLUDES)
endif()

# *****************************************************************************
# Project otclient
# *****************************************************************************
project(otclient)

# *****************************************************************************
# Append cmake search path
# *****************************************************************************
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

# *****************************************************************************
# Include cmake tools
# *****************************************************************************
include(MessageColors)
include(LoggingHelper)
include(GNUInstallDirs)

set(_OTCLIENT_EMSCRIPTEN_COMPILER FALSE)
if(DEFINED CMAKE_CXX_COMPILER)
    string(FIND "${CMAKE_CXX_COMPILER}" "em++" _OTCLIENT_EMSCRIPTEN_COMPILER_POS)
    if(NOT _OTCLIENT_EMSCRIPTEN_COMPILER_POS EQUAL -1)
        set(_OTCLIENT_EMSCRIPTEN_COMPILER TRUE)
    endif()
endif()

if(NOT DEFINED WASM)
    if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten"
            OR CMAKE_CXX_COMPILER_ID MATCHES "Emscripten"
            OR _OTCLIENT_EMSCRIPTEN_COMPILER)
        set(WASM ON CACHE BOOL "Build otclient for WebAssembly targets" FORCE)
    else()
        set(WASM OFF CACHE BOOL "Build otclient for WebAssembly targets" FORCE)
    endif()
endif()

if(WASM)
    message(STATUS "WASM: ON")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten"
        OR CMAKE_CXX_COMPILER_ID MATCHES "Emscripten"
        OR _OTCLIENT_EMSCRIPTEN_COMPILER
        OR WASM)
    set(THREADS_PREFER_PTHREAD_FLAG ON)
    # Add threading and atomics support for WebAssembly builds
    # This fixes linker issues with --shared-memory flag when using pthreads
    # Using add_compile_options ensures flags are applied to all targets including dependencies
    add_compile_options(-pthread -matomics -mbulk-memory)
    add_link_options(-pthread -matomics -mbulk-memory)
endif()

# *****************************************************************************
# Options
# *****************************************************************************
option(OPTIONS_ENABLE_CCACHE "Enable ccache" OFF)
option(OPTIONS_ENABLE_SCCACHE "Use sccache to speed up compilation process" OFF)
option(OPTIONS_ENABLE_IPO "Check and Enable interprocedural optimization (IPO/LTO)" ON)

# *****************************************************************************
# Options Code
# *****************************************************************************

# === CCACHE ===
if(OPTIONS_ENABLE_CCACHE)
	find_program(CCACHE ccache)
	if(CCACHE)
		log_option_enabled("ccache")
		set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE})
		else()
		log_option_disabled("ccache")
	endif()
endif()


# === SCCACHE ===
if(OPTIONS_ENABLE_SCCACHE)
  find_program(SCCACHE_PATH sccache)
  if(SCCACHE_PATH)
    log_option_enabled("sccache")
    set(CMAKE_C_COMPILER_LAUNCHER ${SCCACHE_PATH})
    set(CMAKE_CXX_COMPILER_LAUNCHER ${SCCACHE_PATH})
  else()
    log_option_disabled("sccache")
  endif()
endif()


# === IPO ===
option(OPTIONS_ENABLE_IPO "Check and Enable interprocedural optimization (IPO/LTO)" ON)
if(OPTIONS_ENABLE_IPO)
	log_option_enabled("ipo")

	include(CheckIPOSupported)
	check_ipo_supported(RESULT result OUTPUT output)
	if(result)
		set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
	else()
		log_war("IPO is not supported: ${output}")
	endif()
else()
	log_option_disabled("ipo")
endif()


# *****************************************************************************
# Add project
# *****************************************************************************

# Protobuf
add_subdirectory(src/protobuf)

option(OTCLIENT_BUILD_CLIENT "Build client executable" ON)
option(OTCLIENT_BUILD_TESTS "Build unit tests" ON)

# Src
add_subdirectory(src)

if(OTCLIENT_BUILD_TESTS AND NOT ANDROID)
    enable_testing()
    add_subdirectory(tests)
    log_option_enabled("Build tests")
else()
  if(ANDROID)
    log_option_disabled("Build tests (disabled for Android)")
  else()
    log_option_disabled("Build tests")
  endif()
endif()
