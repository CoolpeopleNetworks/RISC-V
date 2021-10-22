include(${CMAKE_ROOT}/Modules/CMakeDetermineCompiler.cmake)

if(NOT CMAKE_BSV_COMPILER_INIT)
  set(CMAKE_BSV_COMPILER_LIST bsc)
endif()

_cmake_find_compiler(BSV)
mark_as_advanced(CMAKE_BSV_COMPILER)

set(CMAKE_BSV_COMPILER_ID "BSC")
set(CMAKE_BSV_SOURCE_FILE_EXTENSIONS bsv;BSV)
set(CMAKE_BSV_OUTPUT_EXTENSION .bo)

set(CMAKE_BSV_COMPILER_ENV_VAR "BSC")

# configure variables set in this file for fast reload later on
configure_file(${CMAKE_CURRENT_LIST_DIR}/CMakeBSVCompiler.cmake.in
  ${CMAKE_PLATFORM_INFO_DIR}/CMakeBSVCompiler.cmake
  @ONLY
)
