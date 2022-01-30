add_library(Memory INTERFACE)
add_library(Memory::Memory ALIAS Memory)

target_include_directories(Memory INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
