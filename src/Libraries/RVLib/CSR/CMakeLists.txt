add_library(RVLibCSR INTERFACE)
add_library(RVLibCSR::RVLibCSR ALIAS RVLibCSR)

target_include_directories(RVLibCSR INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
