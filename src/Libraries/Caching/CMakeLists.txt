set(SOURCES
    Cache.bsv
    CacheArrayUnit.bsv
#    DirectMappedCache.bsv
)

add_library(Caching STATIC ${SOURCES})
