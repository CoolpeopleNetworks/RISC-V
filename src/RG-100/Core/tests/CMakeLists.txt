find_package(BlueCheck)
#find_package(BSCContrib)

#add_bsim_testbench(ALUTests ALUTests.bsv)
#add_bsim_testbench(CoreTest CoreTest.bsv)

add_executable(CoreTest CoreTest.bsv)
target_link_libraries(CoreTest 
    Memory::Memory
    RG100Core::RG100Core
    RVLib::RVLib
    RecycleBSVLib::RecycleBSVLib
)
#add_bsim_testbench(InstructionDecoderTests InstructionDecoderTests.bsv)
