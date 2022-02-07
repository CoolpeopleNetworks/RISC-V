add_subdirectory(CSR)

add_library(RGLib INTERFACE)
add_library(RGLib::RGLib ALIAS RGLib)

target_include_directories(RGLib INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(RGLib INTERFACE RGLibCSR)

#
# Tests
#
add_executable(ALU_test ALU_test.bsv)
target_link_libraries(ALU_test
    RVLib::RVLib
)
add_test(
    NAME ALU_test
    COMMAND "${CMAKE_SOURCE_DIR}/cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/ALU_test" 
)
