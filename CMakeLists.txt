cmake_minimum_required(VERSION 3.16)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

enable_testing()

project(RISC-V BSV)

set(BSV_DEFINES -D RV32)

add_subdirectory(src)
