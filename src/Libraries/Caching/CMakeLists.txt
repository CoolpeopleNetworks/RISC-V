set(SOURCES
    Cache.bsv
    CacheArrayUnit.bsv
#    DirectMappedCache.bsv
)

add_library(Caching STATIC ${SOURCES})
add_library(Caching::Caching ALIAS Caching)

target_include_directories(Caching PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}Caching${CMAKE_STATIC_LIBRARY_SUFFIX}")
