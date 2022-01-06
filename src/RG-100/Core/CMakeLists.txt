set(SOURCE_FILES 
    ALU.bsv
    RG100Core.bsv
    Instruction.bsv
    InstructionDecoder.bsv
    InstructionExecutor.bsv
    MemoryAccessor.bsv
    RegisterWriteback.bsv
)

add_library(RG100Core STATIC ${SOURCE_FILES})
add_library(RG100Core::RG100Core ALIAS RG100Core)

target_include_directories(RG100Core PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}RG100Core${CMAKE_STATIC_LIBRARY_SUFFIX}")
target_link_libraries(RG100Core RVLib::RVLib RecycleBSVLib::RecycleBSVLib)

add_subdirectory(tests)
