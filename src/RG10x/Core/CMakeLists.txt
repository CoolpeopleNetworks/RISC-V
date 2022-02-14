add_library(RG10xCore INTERFACE)
add_library(RG10xCore::RG10xCore ALIAS RG10xCore)

target_include_directories(RG10xCore INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
