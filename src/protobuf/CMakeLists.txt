# *****************************************************************************
# Project protobuf
# *****************************************************************************
project(protobuf)

if(APPLE)
	set(CMAKE_CXX_STANDARD 11)
endif(APPLE)

find_package(Protobuf REQUIRED)
if(NOT WASM)
        find_package(Threads)
endif()

if(EXISTS ${PROTOBUF_PROTOC_EXECUTABLE})
	message(STATUS "Found Protobuf Compiler: ${PROTOBUF_PROTOC_EXECUTABLE}")
else()
	message(FATAL_ERROR "Could not find Protobuf Compiler")
endif()

if(PROTOBUF_FOUND)

	include_directories(${PROTOBUF_INCLUDE_DIRS})

	file(GLOB ProtoFiles
		"${CMAKE_CURRENT_SOURCE_DIR}/**/*.proto"
		"${CMAKE_CURRENT_SOURCE_DIR}/*.proto"
	)

	if (MSVC)
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

		if (BUILD_STATIC_LIBRARY)
			add_library(${PROJECT_NAME} STATIC ${ProtoFiles})
			set_property(TARGET ${PROJECT_NAME} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
		else()
			add_library(${PROJECT_NAME} ${ProtoFiles})
			set_property(TARGET ${PROJECT_NAME} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
		endif()

		target_compile_options(${PROJECT_NAME} PRIVATE /FS)
		set_target_properties(${PROJECT_NAME} PROPERTIES COMPILE_PDB_NAME ${PROJECT_NAME})
	else()
		add_library(${PROJECT_NAME} ${ProtoFiles})
	endif()

	target_link_libraries(${PROJECT_NAME}
		PUBLIC
			protobuf::libprotobuf
	)
	target_compile_definitions(${PROJECT_NAME} PUBLIC _DISABLE_VECTOR_ANNOTATION _DISABLE_STRING_ANNOTATION)
	target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_BINARY_DIR})

        if(CMAKE_BASE_NAME STREQUAL "em++" AND NOT WASM)
                set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
        endif()

	protobuf_generate(TARGET ${PROJECT_NAME} LANGUAGE cpp)
endif(PROTOBUF_FOUND)
