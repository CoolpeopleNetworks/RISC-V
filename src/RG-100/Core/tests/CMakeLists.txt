add_executable(ALUTests ALUTests.bsv)
target_link_libraries(ALUTests Core::Core)

add_test(NAME ALUTests COMMAND "${CMAKE_CURRENT_BINARY_DIR}/ALUTests")