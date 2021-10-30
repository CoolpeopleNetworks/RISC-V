add_executable(ALUTests ALUTests.bsv)
target_link_libraries(ALUTests Core::Core)
add_bsim_testbench(ALUTests)
