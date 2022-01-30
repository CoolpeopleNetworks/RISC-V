add_subdirectory(CSR)

add_library(RGLib INTERFACE)
add_library(RGLib::RGLib ALIAS RGLib)

target_include_directories(RGLib INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(RGLib INTERFACE RGLibCSR)
