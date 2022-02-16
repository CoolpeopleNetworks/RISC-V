add_library(RGCaches INTERFACE)
add_library(RGCaches::RGCaches ALIAS RGCaches)

target_include_directories(RGCaches INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
