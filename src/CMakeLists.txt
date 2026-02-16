project(otclient)

# *****************************************************************************
# Options
# *****************************************************************************

option(TOGGLE_FRAMEWORK_GRAPHICS "Use Graphics " ON)
option(TOGGLE_FRAMEWORK_SOUND "Use SOUND " ON)
option(TOGGLE_FRAMEWORK_XML "Use XML " ON)
option(TOGGLE_FRAMEWORK_NET "Use NET " ON)
option(TOGGLE_FRAMEWORK_EDITOR "Use Editor " OFF)
option(TOGGLE_DIRECTX "Use DX9 support" OFF)
option(ENABLE_DISCORD_RPC "Use Discord Rich Presence" OFF)
option(TOGGLE_BIN_FOLDER "Use build/bin folder for generate compilation files" OFF)
option(DEBUG_LOG "Enable Debug Log" OFF)
option(ASAN_ENABLED "Build this target with AddressSanitizer" OFF)
option(BUILD_STATIC_LIBRARY "Build using static libraries" OFF)
option(TOGGLE_PRE_COMPILED_HEADER "Use precompiled header (speed up compile)" ON)
option(SPEED_UP_BUILD_UNITY "Compile using build unity for speed up build" ON)

# *****************************************************************************
# Cmake Features
# *****************************************************************************
set(GNUCXX_MINIMUM_VERSION 9)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)


# Make will print more details
set(CMAKE_VERBOSE_MAKEFILE OFF)

# Generate compile_commands.json
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# *****************************************************************************
# Client
# *****************************************************************************
if (MSVC)
  add_executable(${PROJECT_NAME} "" ../cmake/icon/otcicon.rc)
elseif(ANDROID)
  add_library(${PROJECT_NAME} SHARED ${SOURCE_FILES})
else()
  add_executable(${PROJECT_NAME} "")
endif()

# *****************************************************************************
# Options Code
# *****************************************************************************

# Define Framework options for use in compilation
set(FRAMEWORK_DEFINITIONS "")
if (TOGGLE_FRAMEWORK_GRAPHICS)
  set(FRAMEWORK_DEFINITIONS ${FRAMEWORK_DEFINITIONS} -DFRAMEWORK_GRAPHICS)
endif()
if (TOGGLE_FRAMEWORK_SOUND)
  set(FRAMEWORK_DEFINITIONS ${FRAMEWORK_DEFINITIONS} -DFRAMEWORK_SOUND)
endif()
if (TOGGLE_FRAMEWORK_XML)
  set(FRAMEWORK_DEFINITIONS ${FRAMEWORK_DEFINITIONS} -DFRAMEWORK_XML)
endif()
if (TOGGLE_FRAMEWORK_NET)
  set(FRAMEWORK_DEFINITIONS ${FRAMEWORK_DEFINITIONS} -DFRAMEWORK_NET)
endif()

if (TOGGLE_FRAMEWORK_EDITOR)
  set(FRAMEWORK_DEFINITIONS ${FRAMEWORK_DEFINITIONS} -DFRAMEWORK_EDITOR)
endif()
if (ANDROID OR WASM)
  set(FRAMEWORK_DEFINITIONS ${FRAMEWORK_DEFINITIONS} -DOPENGL_ES=2)
endif()

set(VERSION "1.0.0")

# *****************************************************************************
# Definitions code
# *****************************************************************************

# *****************************************************************************
# Sanity Check
# *****************************************************************************

# === GCC Minimum Version ===
if (CMAKE_COMPILER_IS_GNUCXX)
  if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS GNUCXX_MINIMUM_VERSION)
    message(FATAL_ERROR "GCC version must be at least ${GNUCXX_MINIMUM_VERSION}!")
  endif()
endif()


# Multiprocessor compiller
if(CMake_MSVC_PARALLEL)
  if(CMake_MSVC_PARALLEL GREATER 0)
    add_definitions(/MP${CMake_MSVC_PARALLEL})
  else()
    add_definitions(/MP)
  endif()
endif()


# Client options
add_definitions(-DCLIENT)
add_definitions(-DNOMINMAX)
add_definitions(${FRAMEWORK_DEFINITIONS})
add_definitions(-D"VERSION=${VERSION}")
# === Build options ===
message(STATUS "Build type: " ${CMAKE_BUILD_TYPE})
add_definitions(-D"BUILD_TYPE=\\\"${CMAKE_BUILD_TYPE}\\\"")
message(STATUS "Build commit: ${BUILD_COMMIT}")
add_definitions(-D"BUILD_COMMIT=\\\"${BUILD_COMMIT}\\\"")
message(STATUS "Build revision: ${BUILD_REVISION}")
add_definitions(-D"BUILD_REVISION=\\\"${BUILD_REVISION}\\\"")


# *****************************************************************************
# Packages / Libs
# *****************************************************************************
find_package(OpenSSL QUIET)
find_package(PhysFS REQUIRED)
find_package(ZLIB REQUIRED)
find_package(phmap REQUIRED)
find_package(absl CONFIG REQUIRED)
find_package(Protobuf REQUIRED)
find_package(LibLZMA REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(asio REQUIRED)
find_package(Threads REQUIRED)
find_package(STDUUID CONFIG REQUIRED)
find_package(pugixml CONFIG REQUIRED)
find_package(ZLIB REQUIRED)
find_package(httplib CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(utf8cpp REQUIRED)
find_package(Freetype REQUIRED)
find_package(unofficial-inih CONFIG REQUIRED)

find_path(CPPCODEC_INCLUDE_DIRS "cppcodec/base32_crockford.hpp")

if(APPLE)
  # Required for Physfs
  find_library(FOUNDATION Foundation REQUIRED)
  find_library(IOKIT IOKit REQUIRED)
endif()
if(UNIX AND NOT ANDROID AND NOT WASM)
  find_package(X11 REQUIRED)
endif()
if(WIN32)
  find_package(DbgHelp REQUIRED)
endif(WIN32)
if(NOT OPENSSL_FOUND)
  find_package(GMP REQUIRED)
endif()
if(ENABLE_DISCORD_RPC AND NOT ANDROID)
        find_package(DiscordRPC REQUIRED)
        set(OTCLIENT_ENABLE_DISCORD_RPC 1)
        log_option_enabled("Discord Rich Presence")
else()
        set(OTCLIENT_ENABLE_DISCORD_RPC 0)
        log_option_disabled("Discord Rich Presence")
endif()
if(TOGGLE_DIRECTX)
  find_package(DirectX REQUIRED)
endif()
if(TOGGLE_FRAMEWORK_SOUND)
  if(NOT WASM)
    find_package(OpenAL CONFIG REQUIRED)
  endif()
  find_package(VorbisFile REQUIRED)
  find_package(Vorbis CONFIG REQUIRED)
  find_package(Ogg CONFIG REQUIRED)
endif()
if(ANDROID)
  set(LUA_LIBRARY ${LUA_LIBRARY} ${Android_LIBRARIES}/liblua.a)
  set(LUAJIT_INCLUDE_DIR ${LUAJIT_LIBRARY} ${Android_INCLUDES}/luajit)
  set(LUAJIT_LIBRARY ${LUAJIT_LIBRARY} ${Android_LIBRARIES}/libluajit.a)
  set(OpenAL_LIBRARY ${OpenAL_LIBRARY} ${Android_LIBRARIES}/libopenal.a)
  set(MINIZIP_INCLUDE_DIR ${MINIZIP_INCLUDE_DIR} ${Android_INCLUDES}/minizip)
  set(MINIZIP_LIBRARY ${MINIZIP_LIBRARY} ${Android_LIBRARIES}/libminizip.a)
  find_package(game-activity REQUIRED CONFIG)
  find_package(EGL REQUIRED)
else()
  if(NOT WASM)
    find_package(OpenGL REQUIRED)
    find_package(GLEW REQUIRED)
    find_package(LuaJIT REQUIRED)
  else()
    set(LUA_LIBRARY ${LUA_LIBRARY} ${CMAKE_SOURCE_DIR}/browser/include/lua51/liblua.a)
    set(BROWSER_INCLUDE_DIR ${BROWSER_INCLUDE_DIR} ${CMAKE_SOURCE_DIR}/browser/include)
  endif()
endif()

# *****************************************************************************
# OTClient source files configuration
# *****************************************************************************
set(SOURCE_FILES
        framework/core/application.cpp
        framework/core/asyncdispatcher.cpp
        framework/core/binarytree.cpp
        framework/core/clock.cpp
        framework/core/config.cpp
        framework/core/configmanager.cpp
        framework/core/event.cpp
        framework/core/eventdispatcher.cpp
        framework/core/filestream.cpp
        framework/core/logger.cpp
        framework/core/module.cpp
        framework/core/modulemanager.cpp
        framework/core/resourcemanager.cpp
        framework/core/scheduledevent.cpp
        framework/core/unzipper.cpp
        framework/core/unzipper.h
        framework/core/timer.cpp
        framework/discord/discord.cpp
        framework/luaengine/luaexception.cpp
        framework/luaengine/luainterface.cpp
        framework/luaengine/luaobject.cpp
        framework/luaengine/luavaluecasts.cpp
        framework/luafunctions.cpp
        framework/net/connection.cpp
        framework/net/inputmessage.cpp
        framework/net/outputmessage.cpp
        framework/net/protocol.cpp
        framework/net/protocolhttp.cpp
        framework/net/httplogin.cpp
        framework/net/server.cpp
        framework/html/queryselector.cpp
        framework/html/htmlnode.cpp
        framework/html/htmlparser.cpp
        framework/html/htmlmanager.cpp
        framework/html/cssparser.cpp
        framework/otml/otmldocument.cpp
        framework/otml/otmlemitter.cpp
        framework/otml/otmlexception.cpp
        framework/otml/otmlnode.cpp
        framework/otml/otmlparser.cpp
        framework/platform/androidgameactivity.cpp
        framework/platform/androidmanager.cpp
        framework/platform/androidmanager.h
        framework/platform/androidwindow.cpp
        framework/platform/androidwindow.h
        framework/platform/platform.cpp
        framework/platform/platformwindow.cpp
        framework/platform/unixcrashhandler.cpp
        framework/platform/unixplatform.cpp
        framework/platform/win32crashhandler.cpp
        framework/platform/win32platform.cpp
        framework/stdext/demangle.cpp
        framework/stdext/math.cpp
        framework/stdext/net.cpp
        framework/stdext/string.cpp
        framework/stdext/time.cpp
        framework/stdext/uri.cpp
        framework/stdext/qrcodegen.cpp
        framework/util/color.cpp
        framework/util/crypt.cpp
        framework/util/stats.cpp
        framework/proxy/proxy.cpp
        framework/proxy/proxy_client.cpp
        framework/net/packet_player.cpp
        framework/net/packet_recorder.cpp

        client/animatedtext.cpp
        client/animator.cpp
        client/attachableobject.cpp
        client/attachedeffect.cpp
        client/attachedeffectmanager.cpp
        client/client.cpp
        client/container.cpp
        client/creature.cpp
        client/creatures.cpp
        client/effect.cpp
        client/game.cpp
        client/gameconfig.cpp
        client/houses.cpp
        client/item.cpp
        client/itemtype.cpp
        client/lightview.cpp
        client/localplayer.cpp
        client/luafunctions.cpp
        client/luavaluecasts_client.cpp
        client/map.cpp
        client/mapio.cpp
        client/mapview.cpp
        client/minimap.cpp
        client/missile.cpp
        client/outfit.cpp
        client/player.cpp
        client/position.cpp
        client/protocolcodes.cpp
        client/protocolgame.cpp
        client/protocolgameparse.cpp
        client/protocolgamesend.cpp
        client/paperdoll.cpp
        client/paperdollmanager.cpp
        client/spriteappearances.cpp
        client/spritemanager.cpp
        client/statictext.cpp
        client/thing.cpp
        client/thingtype.cpp
        client/thingtypemanager.cpp
        client/tile.cpp
        client/towns.cpp
        client/uicreature.cpp
        client/uigraph.cpp
        client/uiitem.cpp
        client/uieffect.cpp
        client/uimissile.cpp
        client/uimap.cpp
        client/uimapanchorlayout.cpp
        client/uiminimap.cpp
        client/uiprogressrect.cpp
        client/uisprite.cpp
        tools/datdump.cpp
)

if (TOGGLE_FRAMEWORK_GRAPHICS)
  set(SOURCE_FILES ${SOURCE_FILES}
          framework/core/adaptativeframecounter.cpp
          framework/core/graphicalapplication.cpp
          framework/core/garbagecollection.cpp
          framework/input/mouse.cpp
          framework/graphics/animatedtexture.cpp
          framework/graphics/apngloader.cpp
          framework/graphics/bitmapfont.cpp
          framework/graphics/cachedtext.cpp
          framework/graphics/coordsbuffer.cpp
          framework/graphics/textureatlas.cpp
          framework/graphics/drawpool.cpp
          framework/graphics/drawpoolmanager.cpp
          framework/graphics/fontmanager.cpp
          framework/graphics/ttfloader.cpp
          framework/graphics/framebuffer.cpp
          framework/graphics/graphics.cpp
          framework/graphics/image.cpp
          framework/graphics/painter.cpp
          framework/graphics/paintershaderprogram.cpp
          framework/graphics/particle.cpp
          framework/graphics/particleaffector.cpp
          framework/graphics/particleeffect.cpp
          framework/graphics/particleemitter.cpp
          framework/graphics/particlemanager.cpp
          framework/graphics/particlesystem.cpp
          framework/graphics/particletype.cpp
          framework/graphics/shader.cpp
          framework/graphics/shaderprogram.cpp
          framework/graphics/texture.cpp
          framework/graphics/texturemanager.cpp
          framework/graphics/shadermanager.cpp
          framework/platform/win32window.cpp
          framework/platform/x11window.cpp
          framework/ui/uianchorlayout.cpp
          framework/ui/uiboxlayout.cpp
          framework/ui/uigridlayout.cpp
          framework/ui/uihorizontallayout.cpp
          framework/ui/uilayoutflexbox.cpp
          framework/ui/uilayout.cpp
          framework/ui/uimanager.cpp
          framework/ui/uiparticles.cpp
          framework/ui/uitextedit.cpp
          framework/ui/uitranslator.cpp
          framework/ui/uiverticallayout.cpp
          framework/ui/uiwidget.cpp
          framework/ui/uiwidgetbasestyle.cpp
          framework/ui/uiwidgetimage.cpp
          framework/ui/uiwidgettext.cpp
          framework/ui/uiwidgethtml.cpp
          framework/ui/uiqrcode.cpp
  )
endif()

if (TOGGLE_FRAMEWORK_SOUND)
  set(SOURCE_FILES ${SOURCE_FILES}
          framework/sound/combinedsoundsource.cpp
          framework/sound/oggsoundfile.cpp
          framework/sound/soundbuffer.cpp
          framework/sound/soundchannel.cpp
          framework/sound/soundfile.cpp
          framework/sound/soundmanager.cpp
          framework/sound/soundsource.cpp
          framework/sound/streamsoundsource.cpp
          framework/sound/soundeffect.cpp
  )
endif()

if (WASM)
  set(SOURCE_FILES ${SOURCE_FILES}
          framework/platform/browserplatform.cpp
          framework/platform/browserwindow.cpp
          framework/net/webconnection.cpp
  )
endif()

set(OTCLIENT_CORE_TARGETS "")

if(OTCLIENT_BUILD_TESTS AND NOT ANDROID)
  add_library(otclient_core STATIC ${SOURCE_FILES})
  list(APPEND OTCLIENT_CORE_TARGETS otclient_core)
  target_link_libraries(${PROJECT_NAME} PRIVATE otclient_core)
else()
  list(APPEND OTCLIENT_CORE_TARGETS ${PROJECT_NAME})
  target_sources(${PROJECT_NAME} PRIVATE ${SOURCE_FILES})
endif()

foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
  target_link_libraries(${core_target} PUBLIC unofficial::inih::inireader)
endforeach()

if(NOT MSVC)
  target_link_options(${PROJECT_NAME} PUBLIC -flto=auto)
endif()

if(TOGGLE_PRE_COMPILED_HEADER)
  # === PRECOMPILED HEADER ===
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_precompile_headers(${core_target} PRIVATE framework/pch.h)
  endforeach()
  message(STATUS "Use precompiled header: ON")
else()
  message(STATUS "Use precompiled header: OFF")
endif(TOGGLE_PRE_COMPILED_HEADER)

if(SPEED_UP_BUILD_UNITY)
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    set_target_properties(${core_target} PROPERTIES UNITY_BUILD ON)
  endforeach()
  log_option_enabled("Build unity for speed up compilation")
endif(SPEED_UP_BUILD_UNITY)

if(ANDROID)
  target_sources(${PROJECT_NAME} PRIVATE androidmain.cpp main.cpp)
else()
  target_sources(${PROJECT_NAME} PRIVATE main.cpp)
endif()

if(NOT OTCLIENT_BUILD_CLIENT)
  set_target_properties(${PROJECT_NAME} PROPERTIES EXCLUDE_FROM_ALL ON)
  if(MSVC)
    set_target_properties(${PROJECT_NAME} PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD ON)
  endif()
endif()

# *****************************************************************************
# Build flags
# *****************************************************************************
if (NOT MSVC)
  if (CMAKE_COMPILER_IS_GNUCXX)
    foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
      target_compile_options(${core_target} PRIVATE -Wno-deprecated-declarations)
    endforeach()
  endif()
endif()

if(THREADS_HAVE_PTHREAD_ARG)
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_compile_options(${core_target} PUBLIC "-pthread")
  endforeach()
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Release")
  add_definitions(-DNDEBUG)
endif()

# *****************************************************************************
# Definitions code
# *****************************************************************************

# === ASAN ===
if(ASAN_ENABLED)
  log_option_enabled("asan")

  if(MSVC)
    string(REGEX REPLACE "/RTC(su|[1su])" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
      target_compile_options(${core_target} PUBLIC /fsanitize=address)
    endforeach()
    target_link_options(${PROJECT_NAME} PUBLIC /fsanitize=address)
  else()
    foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
      target_compile_options(${core_target} PUBLIC -fsanitize=address)
    endforeach()
    target_link_options(${PROJECT_NAME} PUBLIC -fsanitize=address)
  endif()
else()
  log_option_disabled("asan")
endif()

# === DEBUG LOG ===
# cmake -DDEBUG_LOG=ON ..
if(CMAKE_BUILD_TYPE MATCHES Debug)
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_compile_definitions(${core_target} PRIVATE -DDEBUG_LOG=ON )
  endforeach()
  log_option_enabled("DEBUG LOG")
else()
  log_option_disabled("DEBUG LOG")
endif(CMAKE_BUILD_TYPE MATCHES Debug)

foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
  target_compile_definitions(${core_target} PUBLIC ENABLE_DISCORD_RPC=${OTCLIENT_ENABLE_DISCORD_RPC})
endforeach()

# *****************************************************************************
# Includes and librarys
# *****************************************************************************
if(MSVC)

  # Set variables to have Windows Vista Value so httplib will build 'inet_pton'
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_compile_definitions(${core_target}
            PUBLIC
            NTDDI_VERSION=0x06000000
            _WIN32_WINNT=0x0600
    )

    target_compile_options(${core_target} PUBLIC /MP /FS /Zf /EHsc /bigobj)
  endforeach()

  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    string(REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
    string(REPLACE "/Zi" "/Z7" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
  elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    string(REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
    string(REPLACE "/Zi" "/Z7" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
  elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    string(REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
    string(REPLACE "/Zi" "/Z7" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")
  endif()

  if(BUILD_STATIC_LIBRARY)
    log_option_enabled("STATIC_LIBRARY")
    set(CMAKE_FIND_LIBRARY_SUFFIXES ".lib")
    find_package(Vorbis REQUIRED)
    if(ANDROID)
      find_package(Vorbis CONFIG REQUIRED)
    endif()
    set(_msvc_runtime_targets ${OTCLIENT_CORE_TARGETS} ${PROJECT_NAME})
    list(REMOVE_DUPLICATES _msvc_runtime_targets)
    foreach(msvc_target IN LISTS _msvc_runtime_targets)
      if(TARGET ${msvc_target})
        set_property(TARGET ${msvc_target} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
      endif()
    endforeach()
    set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "")
  else()
    log_option_disabled("STATIC_LIBRARY")
    set(VCPKG_TARGET_TRIPLET "x64-windows" CACHE STRING "")
    set(_msvc_runtime_targets ${OTCLIENT_CORE_TARGETS} ${PROJECT_NAME})
    list(REMOVE_DUPLICATES _msvc_runtime_targets)
    foreach(msvc_target IN LISTS _msvc_runtime_targets)
      if(TARGET ${msvc_target})
        set_property(TARGET ${msvc_target} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
      endif()
    endforeach()
  endif()

  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_include_directories(${core_target}
            PUBLIC
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
            ${LUAJIT_INCLUDE_DIR}
            ${Protobuf_INCLUDE_DIRS}
            ${VORBISFILE_INCLUDE_DIR}
            ${GMP_INCLUDE_DIR}
            ${OPENSSL_INCLUDE_DIR}
            ${PHYSFS_INCLUDE_DIR}
            ${PARALLEL_HASHMAP_INCLUDE_DIRS}
            ${NLOHMANN_JSON_INCLUDE_DIR}
            ${CPPCODEC_INCLUDE_DIRS}
    )
    target_link_libraries(${core_target}
            PUBLIC
            ${LUAJIT_LIBRARY}
            ${CMAKE_THREAD_LIBS_INIT}
            ${PHYSFS_LIBRARY}
            ${ZLIB_LIBRARY}
            ${NLOHMANN_JSON_LIBRARY}
            ${OPENGL_LIBRARIES}
            ${DirectX_LIBRARY}
            ${DirectX_LIBRARIES}
            ${OGG_LIBRARY}
            ${VORBISFILE_LIBRARY}
            ${VORBIS_LIBRARY}
            ${GMP_LIBRARY}
            ${OPENSSL_LIBRARIES}
            ${DBGHELP_LIBRARY}
            ${STDUUID}

            protobuf::libprotobuf protobuf
            absl::log_internal_check_op
            Threads::Threads
            GLEW::GLEW
            asio::asio
            OpenAL::OpenAL
            LibLZMA::LibLZMA
            winmm.lib
            pugixml::pugixml
            fmt::fmt-header-only
            utf8cpp::utf8cpp
            Freetype::Freetype
    )
  endforeach()
elseif(ANDROID)
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_include_directories(${core_target}
            PUBLIC
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
            ${LUAJIT_INCLUDE_DIR}
            ${CMAKE_THREAD_LIBS_INIT}
            ${Protobuf_INCLUDE_DIRS}
            ${GMP_INCLUDE_DIR}
            ${OPENSSL_INCLUDE_DIR}
            ${PHYSFS_INCLUDE_DIR}
            ${EGL_INCLUDE_DIR}
            ${PARALLEL_HASHMAP_INCLUDE_DIRS}
            ${NLOHMANN_JSON_INCLUDE_DIR}
            ${MINIZIP_INCLUDE_DIR}
            ${CPPCODEC_INCLUDE_DIRS}
    )
    target_link_libraries(${core_target}
            PUBLIC
            ${LUA_LIBRARY}
            ${LUAJIT_LIBRARY}
            ${PHYSFS_LIBRARY}
            ${ZLIB_LIBRARY}
            ${NLOHMANN_JSON_LIBRARY}
            ${EGL_LIBRARY}
            ${OGG_LIBRARY}
            ${VORBISFILE_LIBRARY}
            ${VORBIS_LIBRARY}
            ${GMP_LIBRARY}
            ${OpenAL_LIBRARY}
            ${OPENSSL_LIBRARIES}
            ${STDUUID}
            ${MINIZIP_LIBRARY}

            protobuf::libprotobuf protobuf
            absl::log_internal_check_op
            Threads::Threads
            asio::asio
            OpenSLES
            Vorbis::vorbis
            Vorbis::vorbisfile
            LibLZMA::LibLZMA
            game-activity::game-activity
            GLESv3
            android
            log
            pugixml::pugixml
            fmt::fmt-header-only
            utf8cpp::utf8cpp
    )
  endforeach()

elseif(WASM)
  option(WASM_USE_WASM_EXCEPTIONS "Use native WebAssembly exception handling" ON)

  set(_WASM_LONGJMP_MODE "emscripten")
  set(_WASM_EXPORTED_FUNCTIONS "_main,_paste_return")
  set(_WASM_CXX_FLAGS "-O3 -ffast-math -frtti -pthread -fexceptions")
  if(WASM_USE_WASM_EXCEPTIONS)
    set(_WASM_LONGJMP_MODE "wasm")
    set(_WASM_EXPORTED_FUNCTIONS "${_WASM_EXPORTED_FUNCTIONS},_emscripten_longjmp")
    string(APPEND _WASM_CXX_FLAGS " -fwasm-exceptions")
  endif()

  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_include_directories(${core_target}
            PUBLIC
            ${CMAKE_SOURCE_DIR}/src
            ${CMAKE_THREAD_LIBS_INIT}
            ${Protobuf_INCLUDE_DIRS}
            ${GMP_INCLUDE_DIR}
            ${PHYSFS_INCLUDE_DIR}
            ${GLEW_INCLUDE_DIR}
            ${PARALLEL_HASHMAP_INCLUDE_DIRS}
            ${NLOHMANN_JSON_INCLUDE_DIR}
            ${OPENSSL_INCLUDE_DIR}
            ${BROWSER_INCLUDE_DIR}
            ${CPPCODEC_INCLUDE_DIRS}
    )
    target_link_libraries(${core_target}
            PUBLIC
            ${LUA_LIBRARY}
            ${PHYSFS_LIBRARY}
            ${ZLIB_LIBRARY}
            ${PROTOBUF_LIBRARY}
            ${NLOHMANN_JSON_LIBRARY}
            ${GLEW_LIBRARY}
            ${OPENGL_LIBRARIES}
            ${DirectX_LIBRARY}
            ${DirectX_LIBRARIES}
            ${OGG_LIBRARY}
            ${VORBISFILE_LIBRARY}
            ${VORBIS_LIBRARY}
            ${GMP_LIBRARY}
            ${STDUUID}
            ${FOUNDATION}
            ${IOKIT}
            ${OPENSSL_LIBRARY}
            ${OPENSSL_CRYPTO_LIBRARY}
            ${HTTPLIB_LIBRARY}

            protobuf::libprotobuf protobuf
            absl::log_internal_check_op

            Threads::Threads
            asio::asio
            # OpenAL::OpenAL (using emscripten openal api)
            LibLZMA::LibLZMA
            pugixml::pugixml
            ZLIB::ZLIB
            OpenSSL::SSL
            OpenSSL::Crypto
            httplib::httplib
            fmt::fmt
            utf8cpp::utf8cpp
            Ogg::ogg
            Vorbis::vorbisfile
            Vorbis::vorbis
    )
  endforeach()


  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
      target_compile_options(${core_target}
              PRIVATE
              -Wall -Wextra -Wpedantic
      )
    endforeach()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
  endif()

  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${_WASM_CXX_FLAGS}")

  set(WASM_LINK_OPTIONS
          -sINVOKE_RUN=0
          -sEXIT_RUNTIME=1
          -sTEXTDECODER=2
          -sCASE_INSENSITIVE_FS=1
          -lopenal
          -lidbfs.js
          -lwebsocket.js
          -sEXPORTED_RUNTIME_METHODS=ccall
          "-sEXPORTED_FUNCTIONS=${_WASM_EXPORTED_FUNCTIONS}"
          -sINCOMING_MODULE_JS_API=[locateFile,preRun,postRun,print,printErr,canvas,setStatus,monitorRunDependencies]
          -sFORCE_FILESYSTEM
          -sMALLOC=dlmalloc
          "-sSUPPORT_LONGJMP=${_WASM_LONGJMP_MODE}"
          -sWEBSOCKET_SUBPROTOCOL=binary
          -sOFFSCREENCANVAS_SUPPORT=1
          -sOFFSCREEN_FRAMEBUFFER
          -sENVIRONMENT=web,worker
          -sPROXY_TO_PTHREAD
          -sFULL_ES2=1
          -sMIN_WEBGL_VERSION=2
          -sMAX_WEBGL_VERSION=2
          -sUSE_PTHREADS=1
          -sFETCH=1
          -sPTHREAD_POOL_SIZE=navigator.hardwareConcurrency
          -sALLOW_MEMORY_GROWTH=1
          --preload-file=../otclientrc.lua@otclientrc.lua
          --preload-file=../init.lua@init.lua
          --preload-file=../data@data
          --preload-file=../mods@mods
          --preload-file=../modules@modules
          --shell-file=../browser/shell.html
          --use-preload-cache
  )

  if(WASM_USE_WASM_EXCEPTIONS)
    list(APPEND WASM_LINK_OPTIONS "-sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE=['emscripten_longjmp']")
  endif()

  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    list(APPEND WASM_LINK_OPTIONS -sASSERTIONS=1)
  endif()

  target_link_options(${PROJECT_NAME} PRIVATE ${WASM_LINK_OPTIONS})
  string(REPLACE ";" " " _WASM_LINK_LOG "${WASM_LINK_OPTIONS}")
  message(STATUS "WASM link options: ${_WASM_LINK_LOG}")
  set(CMAKE_EXECUTABLE_SUFFIX ".html")
  set(VCPKG_TARGET_TRIPLET "wasm32-emscripten" CACHE STRING "")

else() # Linux
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_include_directories(${core_target}
            PUBLIC
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
            ${LUAJIT_INCLUDE_DIR}
            ${CMAKE_THREAD_LIBS_INIT}
            ${Protobuf_INCLUDE_DIRS}
            ${GMP_INCLUDE_DIR}
            ${PHYSFS_INCLUDE_DIR}
            ${GLEW_INCLUDE_DIR}
            ${PARALLEL_HASHMAP_INCLUDE_DIRS}
            ${NLOHMANN_JSON_INCLUDE_DIR}
            ${OPENSSL_INCLUDE_DIR}
            ${CPPCODEC_INCLUDE_DIRS}
    )
    target_link_libraries(${core_target}
            PUBLIC
            ${LUAJIT_LIBRARY}
            ${PHYSFS_LIBRARY}
            ${ZLIB_LIBRARY}
            ${NLOHMANN_JSON_LIBRARY}
            ${GLEW_LIBRARY}
            ${OPENGL_LIBRARIES}
            ${DirectX_LIBRARY}
            ${DirectX_LIBRARIES}
            ${OGG_LIBRARY}
            ${VORBISFILE_LIBRARY}
            ${VORBIS_LIBRARY}
            ${GMP_LIBRARY}
            ${STDUUID}
            ${FOUNDATION}
            ${IOKIT}
            ${OPENSSL_LIBRARY}
            ${OPENSSL_CRYPTO_LIBRARY}
            ${HTTPLIB_LIBRARY}

            protobuf::libprotobuf protobuf
            absl::log_internal_check_op
            Threads::Threads
            X11::X11
            asio::asio
            OpenAL::OpenAL
            LibLZMA::LibLZMA
            pugixml::pugixml
            ZLIB::ZLIB
            OpenSSL::SSL
            OpenSSL::Crypto
            httplib::httplib
            fmt::fmt-header-only
            utf8cpp::utf8cpp
            Ogg::ogg
            Vorbis::vorbisfile
            Vorbis::vorbis
            Freetype::Freetype
    )
  endforeach()

  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
      target_compile_options(${core_target}
              PRIVATE
              -Wall -Wextra -Wpedantic
      )
    endforeach()
  endif()

endif()
if(ENABLE_DISCORD_RPC AND NOT ANDROID)
  foreach(core_target IN LISTS OTCLIENT_CORE_TARGETS)
    target_link_libraries(${core_target} PUBLIC ${DISCORDRPC_LIBRARY})
  endforeach()
endif()

# *****************************************************************************
# Enable otclient console only for debug build
# *****************************************************************************
if(WIN32)
  set_target_properties(${PROJECT_NAME}
          PROPERTIES
          LINK_FLAGS_DEBUG "/SUBSYSTEM:CONSOLE"
          LINK_FLAGS_RELEASE "/SUBSYSTEM:windows /ENTRY:mainCRTStartup"
          LINK_FLAGS_RELWITHDEBINFO "/SUBSYSTEM:CONSOLE"
          LINK_FLAGS_MINSIZEREL "/SUBSYSTEM:windows /ENTRY:mainCRTStartup"
  )
endif(WIN32)

if(ANDROID)
  set(CMAKE_SHARED_LINKER_FLAGS "-fuse-ld=lld")
  set(CMAKE_EXE_LINKER_FLAGS "-fuse-ld=lld")
endif()

# *****************************************************************************
# Link compilation files folder
# *****************************************************************************

## Link compilation files to build/bin folder, else link to the main dir
if (TOGGLE_BIN_FOLDER)
  set_target_properties(${PROJECT_NAME}
          PROPERTIES
          RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
  )
else()
  set_target_properties(${PROJECT_NAME}
          PROPERTIES
          RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/"
  )
endif()
