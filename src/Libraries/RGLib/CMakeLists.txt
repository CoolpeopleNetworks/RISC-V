add_subdirectory(CSR)

add_library(RGLib INTERFACE)
add_library(RGLib::RGLib ALIAS RGLib)

target_include_directories(RGLib INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(RGLib 
    INTERFACE 
    RGLibCSR::RGLibCSR
    TileLink::TileLink
)

#
# Tests
#
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_test.bsv")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WE)
    add_executable(${TEST_TARGET} ${TEST_FILE})
    target_link_libraries(${TEST_TARGET}
        RVLib::RVLib
        RGLibCSR::RGLibCSR
    )
    add_test(
        NAME ${TEST_TARGET}
        COMMAND "${CMAKE_SOURCE_DIR}/cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    )
endforeach()
