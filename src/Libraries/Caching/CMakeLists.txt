add_library(Caching INTERFACE)
add_library(Caching::Caching ALIAS Caching)

target_include_directories(Caching INTERFACE "${RECYCLE_BSV_LIB_DIR}")
