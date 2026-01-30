vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO freetype/freetype
    REF VER-2-13-3
    SHA512 be4411f0e1cd55ccabf0ffe20c7197d24f366e389ad3de440d2a79de5e50e0f9a1b4f46f28e5ebf0d76f3c71fe50c80d43d0b68d0f5ae9ba11b039b73cccfd9e
    HEAD_REF master
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        brotli  FT_REQUIRE_BROTLI
        bzip2   FT_REQUIRE_BZIP2
        error-strings   FT_ENABLE_ERROR_STRINGS
        png     FT_REQUIRE_PNG
        zlib    FT_REQUIRE_ZLIB
)

# Force pthread flags for all C/C++ compilations in Emscripten
set(EXTRA_C_FLAGS "")
set(EXTRA_CXX_FLAGS "")
if(VCPKG_TARGET_TRIPLET MATCHES "emscripten" OR VCPKG_TARGET_TRIPLET MATCHES "wasm")
    # Add atomics and bulk-memory support for shared memory/threading
    # Append to existing VCPKG flags to preserve triplet settings
    set(EXTRA_C_FLAGS "${VCPKG_C_FLAGS} -pthread -matomics -mbulk-memory")
    set(EXTRA_CXX_FLAGS "${VCPKG_CXX_FLAGS} -pthread -matomics -mbulk-memory")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DFT_DISABLE_HARFBUZZ=ON
OPTIONS_DEBUG
        "-DCMAKE_C_FLAGS_DEBUG=${EXTRA_C_FLAGS} ${CMAKE_C_FLAGS_DEBUG}"
        "-DCMAKE_CXX_FLAGS_DEBUG=${EXTRA_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG}"
OPTIONS_RELEASE
        "-DCMAKE_C_FLAGS_RELEASE=${EXTRA_C_FLAGS} ${CMAKE_C_FLAGS_RELEASE}"
        "-DCMAKE_CXX_FLAGS_RELEASE=${EXTRA_CXX_FLAGS} ${CMAKE_CXX_FLAGS_RELEASE}"
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/freetype)
vcpkg_fixup_pkgconfig()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

# Cleanup
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${SOURCE_PATH}/LICENSE.TXT" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
