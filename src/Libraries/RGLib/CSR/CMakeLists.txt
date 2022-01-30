add_library(RGLibCSR INTERFACE)
add_library(RGLibCSR::RGLibCSR ALIAS RGLibCSR)

target_include_directories(RGLibCSR INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
