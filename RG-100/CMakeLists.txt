cmake_minimum_required(VERSION 3.16)

project(RG-100)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake")

add_subdirectory(src)
add_subdirectory(test)
