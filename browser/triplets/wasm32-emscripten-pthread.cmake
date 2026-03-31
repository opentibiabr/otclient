set(VCPKG_TARGET_ARCHITECTURE wasm32)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Emscripten)
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "$ENV{EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")

# Force pthread support with atomics and bulk-memory for all packages
# These flags are required for shared memory support in WebAssembly
# FMT_USE_CONSTEVAL=0: disables fmt's consteval format-string constructor which
# emscripten's Clang cannot satisfy inside catch blocks (SPDLOG_LOGGER_CATCH).
# FMT_USE_NONTYPE_TEMPLATE_ARGS=0: disables C++20 non-type template args in fmt
# which are not reliably supported by the emscripten toolchain.
set(VCPKG_C_FLAGS "-pthread -matomics -mbulk-memory -DFMT_USE_CONSTEVAL=0 -DFMT_USE_NONTYPE_TEMPLATE_ARGS=0")
set(VCPKG_CXX_FLAGS "-pthread -matomics -mbulk-memory -DFMT_USE_CONSTEVAL=0 -DFMT_USE_NONTYPE_TEMPLATE_ARGS=0")
set(VCPKG_LINKER_FLAGS "-pthread -matomics -mbulk-memory")

# Also set as CMAKE_*_FLAGS to ensure they're applied universally
set(VCPKG_CMAKE_CONFIGURE_OPTIONS 
    "-DCMAKE_C_FLAGS=-pthread -matomics -mbulk-memory -DFMT_USE_CONSTEVAL=0 -DFMT_USE_NONTYPE_TEMPLATE_ARGS=0"
    "-DCMAKE_CXX_FLAGS=-pthread -matomics -mbulk-memory -DFMT_USE_CONSTEVAL=0 -DFMT_USE_NONTYPE_TEMPLATE_ARGS=0"
)
