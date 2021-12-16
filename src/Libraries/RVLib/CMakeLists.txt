set(SOURCES
    RVBypass.bsv
    RVCSRFile.bsv
    RVRegisterFile.bsv
    RVTypes.bsv
)

add_library(RVLib STATIC ${SOURCES})
add_library(RVLib::RVLib ALIAS RVLib)

target_link_libraries(RVLib PUBLIC RecycleBSVLib::RecycleBSVLib)
target_include_directories(RVLib PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}RVLib${CMAKE_STATIC_LIBRARY_SUFFIX}")
