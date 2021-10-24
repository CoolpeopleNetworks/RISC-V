set(SOURCES
    TileLink.bsv
)

add_library(TileLink STATIC ${SOURCES})
add_library(TileLink::TileLink ALIAS TileLink)

target_include_directories(TileLink PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}TileLink${CMAKE_STATIC_LIBRARY_SUFFIX}")
