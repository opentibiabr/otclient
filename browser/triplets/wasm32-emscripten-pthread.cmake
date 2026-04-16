set(VCPKG_TARGET_ARCHITECTURE wasm32)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Emscripten)
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "$ENV{EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")

# Force pthread support with atomics and bulk-memory for all packages
# These flags are required for shared memory support in WebAssembly
set(VCPKG_C_FLAGS "-pthread -matomics -mbulk-memory")
set(VCPKG_CXX_FLAGS "-pthread -matomics -mbulk-memory")
set(VCPKG_LINKER_FLAGS "-pthread -matomics -mbulk-memory")

# Also set as CMAKE_*_FLAGS to ensure they're applied universally
set(VCPKG_CMAKE_CONFIGURE_OPTIONS 
    "-DCMAKE_C_FLAGS=-pthread -matomics -mbulk-memory"
    "-DCMAKE_CXX_FLAGS=-pthread -matomics -mbulk-memory"
)
