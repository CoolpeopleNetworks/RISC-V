find_package(BlueCheck)

add_executable(ALUTests ALUTests.bsv)
target_link_libraries(ALUTests RG100Core::RG100Core RVLib::RVLib BlueCheck::BlueCheck)
add_bsim_testbench(ALUTests)

add_executable(CoreTest CoreTest.bsv)
target_link_libraries(CoreTest RG100Core::RG100Core RVLib::RVLib BlueCheck::BlueCheck)
add_bsim_testbench(CoreTest)

add_executable(InstructionDecoderTests InstructionDecoderTests.bsv)
target_link_libraries(InstructionDecoderTests RG100Core::RG100Core RVLib::RVLib BlueCheck::BlueCheck)
add_bsim_testbench(InstructionDecoderTests)
