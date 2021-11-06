set(SOURCE_FILES 
    ALU.bsv
    Core.bsv
    CSRFile.bsv
    Instruction.bsv
    InstructionDecoder.bsv
    InstructionExecutor.bsv
    RegisterFile.bsv
)

add_library(Core STATIC ${SOURCE_FILES})
add_library(Core::Core ALIAS Core)

target_include_directories(Core PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}Core${CMAKE_STATIC_LIBRARY_SUFFIX}")
target_link_libraries(Core RVLib::RVLib RecycleBSVLib::RecycleBSVLib)

add_subdirectory(tests)
