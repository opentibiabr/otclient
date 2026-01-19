vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO benhoyt/inih
    REF "r${VERSION}"
    SHA512 d69f488299c1896e87ddd3dd20cd9db5848da7afa4c6159b8a99ba9a5d33f35cadfdb9f65d6f2fe31decdbadb8b43bf610ff2699df475e1f9ff045e343ac26ae
    HEAD_REF master
)

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        cpp INIH_WITH_INI_READER
)

set(INIH_WITH_INI_READER OFF)
if(DEFINED VCPKG_FEATURES)
    if("cpp" IN_LIST VCPKG_FEATURES)
        set(INIH_WITH_INI_READER ON)
    endif()
else()
    # Older vcpkg baselines may not populate VCPKG_FEATURES, but we always need INIReader.
    set(INIH_WITH_INI_READER ON)
endif()

set(FEATURE_OPTIONS "")
if(INIH_WITH_INI_READER)
    list(APPEND FEATURE_OPTIONS "-DINIH_WITH_INI_READER=ON")
endif()

if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    set(INIH_CONFIG_DEBUG ON)
else()
    set(INIH_CONFIG_DEBUG OFF)
endif()

configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/unofficial-inihConfig.cmake.in"
    "${CURRENT_PACKAGES_DIR}/share/unofficial-inih/unofficial-inihConfig.cmake"
    @ONLY
)

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_configure_cmake(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS_DEBUG
        ${FEATURE_OPTIONS}
        "-DINIH_WITH_DEBUG=ON"
    OPTIONS_RELEASE
        ${FEATURE_OPTIONS}
        "-DINIH_WITH_DEBUG=OFF"
)

vcpkg_install_cmake()

vcpkg_copy_pdbs()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")

configure_file("${CMAKE_CURRENT_LIST_DIR}/usage" "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" COPYONLY)
