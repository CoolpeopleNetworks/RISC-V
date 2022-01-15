find_package(BlueCheck)
find_package(BSCContrib)

add_bsim_testbench(ALUTests ALUTests.bsv)
add_bsim_testbench(CoreTest CoreTest.bsv)

#add_bsim_testbench(InstructionDecoderTests InstructionDecoderTests.bsv)
