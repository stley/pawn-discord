cmake_minimum_required(VERSION 3.20)
project(PawnBuild NONE)   # no C/C++ languages

# --- Hardcoded pawn compiler location (edit this to your actual path) ---
# Example Windows: C:/tools/pawn/pawncc.exe
# Example WSL / Linux: /usr/local/bin/pawncc
find_program(PAWNCC NAMES pawncc pawncc.exe)

if(NOT EXISTS "${PAWNCC}")
  message(FATAL_ERROR "pawncc not found at: ${PAWNCC}")
endif()

# include dir (local workspace)
set(PAWN_INCLUDES "-i${CMAKE_SOURCE_DIR}/include")

# output directory (build/amx/*.amx)
set(OUTPUT_DIR "${CMAKE_BINARY_DIR}/amx")
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

# compile all top-level src/*.pwn (non-recursive)
file(GLOB PAWN_SOURCES CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/src/*.pwn")

if(NOT PAWN_SOURCES)
  message(WARNING "No .pwn files found in ${CMAKE_SOURCE_DIR}/src")
endif()

set(AMX_OUTPUTS)
foreach(_src IN LISTS PAWN_SOURCES)
  get_filename_component(_base "${_src}" NAME_WE)
  set(_out "${OUTPUT_DIR}/${_base}.amx")

  add_custom_command(
    OUTPUT "${_out}"
    DEPENDS "${_src}"
    COMMAND "${PAWNCC}" "${_src}" ${PAWN_INCLUDES} "-o${_out}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Compiling Pawn: ${_src} -> ${_out}"
    VERBATIM
  )

  list(APPEND AMX_OUTPUTS "${_out}")
endforeach()

# one top-level target to build all amx files
add_custom_target(all_amx DEPENDS ${AMX_OUTPUTS})

# simple status output
message(STATUS "pawncc: ${PAWNCC}")
message(STATUS "pawn sources: ${PAWN_SOURCES}")
message(STATUS "amx output -> ${OUTPUT_DIR}")
