#include(bluespec)

set(SOURCE_FILES 
    ALU.bsv
    Common.bsv
    Core.bsv
    Instruction.bsv
    InstructionDecoder.bsv
    InstructionExecutor.bsv
    RegisterFile.bsv
)

add_library(Core STATIC ${SOURCE_FILES})
target_link_libraries(Core RecycleBSVLib::RecycleBSVLib)
