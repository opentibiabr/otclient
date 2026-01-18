cmake_minimum_required(VERSION 3.16)
project(inih LANGUAGES C CXX)

option(INIH_WITH_INI_READER "Build C++ INIReader library" OFF)
option(INIH_WITH_DEBUG "Enable debug features" OFF)

add_library(inih ini.c)
set_target_properties(inih PROPERTIES OUTPUT_NAME inih)
target_include_directories(inih
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:include>
)

if(INIH_WITH_DEBUG)
    target_compile_definitions(inih PUBLIC INI_DEBUG)
endif()

if(INIH_WITH_INI_READER)
    add_library(INIReader cpp/INIReader.cpp)
    set_target_properties(INIReader PROPERTIES OUTPUT_NAME INIReader)
    target_compile_features(INIReader PUBLIC cxx_std_11)
    target_include_directories(INIReader
        PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/cpp>
            $<INSTALL_INTERFACE:include>
    )
    target_link_libraries(INIReader PUBLIC inih)
endif()

include(GNUInstallDirs)

install(TARGETS inih
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(INIH_WITH_INI_READER)
    install(TARGETS INIReader
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif()

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/ini.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
if(INIH_WITH_INI_READER)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cpp/INIReader.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
endif()
