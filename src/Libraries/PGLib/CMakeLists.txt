add_subdirectory(CSR)

add_library(PGLib INTERFACE)
add_library(PGLib::PGLib ALIAS PGLib)

target_include_directories(PGLib INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(PGLib 
    INTERFACE 
    PGLibCSR::PGLibCSR
    TileLink::TileLink
)

#
# Tests
#
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_tb.bsv")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WE)
    add_executable(${TEST_TARGET} ${TEST_FILE})
    target_compile_definitions(${TEST_TARGET} PUBLIC
        ${BASE_ISA}
    )
    target_link_libraries(${TEST_TARGET}
        RVLib::RVLib
        PGLibCSR::PGLibCSR
    )
    add_test(
        NAME ${TEST_TARGET}
        COMMAND "${CMAKE_SOURCE_DIR}/cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    )
endforeach()
