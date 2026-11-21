# GitHub returns HTTP 503 for commit-patch URLs with ?full_index=1; use plain .patch (SHA512 updated for its content).
vcpkg_download_distfile(SPDLOG_BACKPORT_3541_PATCH
    URLS https://github.com/gabime/spdlog/commit/1685e694c5cd8328280c48f8b94b1281c17c6fee.patch
    FILENAME spdlog-backport-3541.patch
    SHA512 ae6bd65fc986d764baf49057d0b5c42d0e0fbd2ae6c9ac007d76450396bb439835d5df2e90697aecea67af3b3388dbafd974cd52e1f05d9a5131ecbd7ed50a9b
)
vcpkg_download_distfile(SPDLOG_BACKPORT_3543_PATCH
    URLS https://github.com/gabime/spdlog/commit/d5af52d903ed69f96c7350155e94aeff248b31eb.patch
    FILENAME spdlog-backport-3543.patch
    SHA512 f867fb3ae7aa4802cc0cfeeca7594d0c994f28b7a39324aec86be9fab1784dceaf837833f8a3f73cc983a5e9c0f018022f8cff8a3771beae2f65f6f7e4f01f1f
)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO gabime/spdlog
    REF "v${VERSION}"
    SHA512 8df117055d19ff21c9c9951881c7bdf27cc0866ea3a4aa0614b2c3939cedceab94ac9abaa63dc4312b51562b27d708cb2f014c68c603fd1c1051d3ed5c1c3087
    HEAD_REF v1.x
    PATCHES
        "${SPDLOG_BACKPORT_3541_PATCH}"
        "${SPDLOG_BACKPORT_3543_PATCH}"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        benchmark SPDLOG_BUILD_BENCH
        fmt       SPDLOG_FMT_EXTERNAL
        wchar     SPDLOG_WCHAR_SUPPORT
    INVERTED_FEATURES
        fmt       SPDLOG_USE_STD_FORMAT
        tz-offset SPDLOG_NO_TZ_OFFSET
)

# SPDLOG_WCHAR_FILENAMES can only be configured in triplet file since it is an alternative (not additive)
if(NOT DEFINED SPDLOG_WCHAR_FILENAMES)
    set(SPDLOG_WCHAR_FILENAMES OFF)
endif()
if(NOT VCPKG_TARGET_IS_WINDOWS AND SPDLOG_WCHAR_FILENAMES)
    message(FATAL_ERROR "Build option 'SPDLOG_WCHAR_FILENAMES' is for Windows.")
endif()

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" SPDLOG_BUILD_SHARED)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DSPDLOG_INSTALL=ON
        -DSPDLOG_BUILD_SHARED=${SPDLOG_BUILD_SHARED}
        -DSPDLOG_WCHAR_FILENAMES=${SPDLOG_WCHAR_FILENAMES}
        -DSPDLOG_BUILD_EXAMPLE=OFF
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/spdlog)
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()

if(NOT VCPKG_BUILD_TYPE)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/spdlog.pc" " -lspdlog" " -lspdlogd")
endif()

# add support for integration other than cmake
if(SPDLOG_FMT_EXTERNAL)
    vcpkg_replace_string(${CURRENT_PACKAGES_DIR}/include/spdlog/tweakme.h
        "// #define SPDLOG_FMT_EXTERNAL"
        "#ifndef SPDLOG_FMT_EXTERNAL\n#define SPDLOG_FMT_EXTERNAL\n#endif"
    )
endif()
if(SPDLOG_USE_STD_FORMAT)
    vcpkg_replace_string(${CURRENT_PACKAGES_DIR}/include/spdlog/tweakme.h
        "// #define SPDLOG_USE_STD_FORMAT"
	"#ifndef SPDLOG_USE_STD_FORMAT\n#define SPDLOG_USE_STD_FORMAT\n#endif"
    )
endif()
if(SPDLOG_WCHAR_SUPPORT)
    vcpkg_replace_string(${CURRENT_PACKAGES_DIR}/include/spdlog/tweakme.h
        "// #define SPDLOG_WCHAR_TO_UTF8_SUPPORT"
        "#ifndef SPDLOG_WCHAR_TO_UTF8_SUPPORT\n#define SPDLOG_WCHAR_TO_UTF8_SUPPORT\n#endif"
    )
endif()
if(SPDLOG_WCHAR_FILENAMES)
    vcpkg_replace_string(${CURRENT_PACKAGES_DIR}/include/spdlog/tweakme.h
        "// #define SPDLOG_WCHAR_FILENAMES"
        "#ifndef SPDLOG_WCHAR_FILENAMES\n#define SPDLOG_WCHAR_FILENAMES\n#endif"
    )
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/include/spdlog/fmt/bundled"
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
