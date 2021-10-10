include(bluespec)

set(SOURCE_FILES 
    ALU.bsv
    Core.bsv
    Common.bsv
    Instruction.bsv
    InstructionDecoder.bsv
    MemoryController.bsv
    RegisterFile.bsv
    TileLink.bsv
)

add_bluespec_simulation(mkCoreTest
    tests/CoreTest.bsv
    ${SOURCE_FILES}
)

# add_bluespec_verilog_package(mkCore
#     Core.bsv
#     ${SOURCE_FILES}
# )