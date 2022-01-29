add_library(TileLink INTERFACE)
add_library(TileLink::TileLink ALIAS TileLink)

target_include_directories(TileLink INTERFACE "${RECYCLE_BSV_LIB_DIR}")
