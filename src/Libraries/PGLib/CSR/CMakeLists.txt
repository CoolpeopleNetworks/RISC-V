add_library(PGLibCSR INTERFACE)
add_library(PGLibCSR::PGLibCSR ALIAS PGLibCSR)

target_include_directories(PGLibCSR INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
