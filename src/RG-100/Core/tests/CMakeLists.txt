find_package(BlueCheck)

add_executable(ALUTests ALUTests.bsv)
target_link_libraries(ALUTests Core::Core RVLib::RVLib BlueCheck::BlueCheck)
add_bsim_testbench(ALUTests)

add_executable(InstructionDecoderTests InstructionDecoderTests.bsv)
target_link_libraries(InstructionDecoderTests Core::Core RVLib::RVLib BlueCheck::BlueCheck)
add_bsim_testbench(InstructionDecoderTests)
