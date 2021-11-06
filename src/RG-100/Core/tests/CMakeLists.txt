add_executable(ALUTests ALUTests.bsv)
target_link_libraries(ALUTests Core::Core RVLib::RVLib)
add_bsim_testbench(ALUTests)

add_executable(InstructionDecoderTests InstructionDecoderTests.bsv)
target_link_libraries(InstructionDecoderTests Core::Core RVLib::RVLib)
add_bsim_testbench(InstructionDecoderTests)
