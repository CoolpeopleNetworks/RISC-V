cmake_minimum_required(VERSION 3.21)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

enable_testing()

project(RISC-V BSV)

add_subdirectory(src)
add_subdirectory(test)
