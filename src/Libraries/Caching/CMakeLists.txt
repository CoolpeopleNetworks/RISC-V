list(APPEND BSC_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

set(SOURCES
    Cache.bsv
    CacheArrayUnit.bsv
#    DirectMappedCache.bsv
)

add_library(Caching STATIC ${SOURCES})
