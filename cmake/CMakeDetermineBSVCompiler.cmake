# Locate the 'bsc' compiler
find_program(CMAKE_BSV_COMPILER NAMES bsc REQUIRED)
mark_as_advanced(CMAKE_BSV_COMPILER)

set(CMAKE_BSV_SOURCE_FILE_EXTENSIONS bsv;BSV)
set(CMAKE_BSV_OUTPUT_EXTENSION .ba)
set(CMAKE_BSV_COMPILER_ENV_VAR "BSC")

# configure variables set in this file for fast reload later on
configure_file(${CMAKE_CURRENT_LIST_DIR}/CMakeBSVCompiler.cmake.in
  ${CMAKE_PLATFORM_INFO_DIR}/CMakeBSVCompiler.cmake
  @ONLY
  )
