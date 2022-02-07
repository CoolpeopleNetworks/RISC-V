find_package(BlueCheck)

add_executable(RG10xSim Simulator.bsv)
target_link_libraries(RG10xSim 
    RG10xCore::RG10xCore
    RVLib::RVLib
    RGLib::RGLib
    RecycleBSVLib::RecycleBSVLib
)

target_compile_definitions(RG10xSim PUBLIC
    ${BASE_ISA}
    EXTENSION_ZICSR
    #DISABLE_BRANCH_PREDICTION
)

#
# Tests
#
add_executable(MemorySystem_test MemorySystem_test.bsv)
target_compile_definitions(MemorySystem_test PUBLIC
    ${BASE_ISA}
)
target_link_libraries(MemorySystem_test
    RVLib::RVLib
    RGLib::RGLib
)
add_test(
    NAME MemorySystem_test
    COMMAND "${CMAKE_SOURCE_DIR}/cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/MemorySystem_test" 
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
