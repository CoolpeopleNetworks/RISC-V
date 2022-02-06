find_package(BlueCheck)

add_executable(RG100Sim Simulator.bsv)
target_link_libraries(RG100Sim 
    RG100Core::RG100Core
    RVLib::RVLib
    RGLib::RGLib
    RecycleBSVLib::RecycleBSVLib
)

target_compile_definitions(RG100Sim PUBLIC
    RV32
    EXTENSION_ZICSR
    #DISABLE_PIPELINING
    #DISABLE_BRANCH_PREDICTION
)
