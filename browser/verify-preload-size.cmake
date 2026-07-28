# verify-preload-size.cmake
# POST_BUILD verification that the WASM data file is under the size limit.
# This catches silent failures of --exclude-file where the pattern doesn't match.
#
# Usage:
#   cmake -D DATA_FILE=/path/to/otclient.data -P verify-preload-size.cmake
#
# Exits with error if DATA_FILE exceeds MAX_SIZE bytes.

set(MAX_SIZE 209715200)  # 200 MiB

if(NOT DEFINED DATA_FILE)
  message(FATAL_ERROR "DATA_FILE not defined")
endif()

if(NOT EXISTS "${DATA_FILE}")
  message(FATAL_ERROR "Data file not found: ${DATA_FILE}")
endif()

file(SIZE "${DATA_FILE}" DATA_SIZE)

if(DATA_SIZE GREATER MAX_SIZE)
  math(EXPR SIZE_MB "${DATA_SIZE} / 1048576")
  math(EXPR MAX_MB "${MAX_SIZE} / 1048576")
  message(FATAL_ERROR 
    "Preload data file too large: ${SIZE_MB} MiB (max ${MAX_MB} MiB).\n"
    "The --exclude-file pattern may not have matched.\n"
    "File: ${DATA_FILE}"
  )
else()
  math(EXPR SIZE_MB "${DATA_SIZE} / 1048576")
  message(STATUS "Preload data file size OK: ${SIZE_MB} MiB (max 200 MiB)")
endif()
