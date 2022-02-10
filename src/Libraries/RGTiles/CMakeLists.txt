add_library(RGTiles INTERFACE)
add_library(RGTiles::RGTiles ALIAS RGTiles)

target_include_directories(RGTiles INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
