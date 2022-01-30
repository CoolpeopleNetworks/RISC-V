add_subdirectory(tests)

add_library(RG100Core INTERFACE)
add_library(RG100Core::RG100Core ALIAS RG100Core)

target_include_directories(RG100Core INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
