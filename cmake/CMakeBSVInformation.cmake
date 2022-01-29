include(CMakeLanguageInformation)

# Load compiler-specific information.
if(CMAKE_BSV_COMPILER_ID)
  include(Compiler/${CMAKE_BSV_COMPILER_ID}-BSV)
endif()

include(CMakeCommonLanguageInclude)

# compile COMMAND bsc ${BSC_COMMON_FLAGS} ${BSC_DEFINES} -sim -q -u -bdir "${CMAKE_CURRENT_BINARY_DIR}" -p "%/Libraries:${CMAKE_CURRENT_SOURCE_DIR}:${BSV_MODULE_DIRS}" -o "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}" "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE}"
# link COMMAND bsc ${BSC_COMMON_FLAGS} ${BSC_DEFINES} -sim -q -u -e mk${TARGET} -bdir "${CMAKE_CURRENT_BINARY_DIR}" -p "${CMAKE_CURRENT_SOURCE_DIR}:${BSV_MODULE_DIRS}" -o "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}"

if(NOT CMAKE_BSV_COMPILE_OBJECT)
    set(CMAKE_BSV_COMPILE_OBJECT 
        "<CMAKE_BSV_COMPILER> -v -o <OBJECT> -beginIncludes <INCLUDES> -endIncludes <SOURCE>"
    )
endif()

if(NOT CMAKE_BSV_LINK_EXECUTABLE)
    set(CMAKE_BSV_LINK_EXECUTABLE 
    "<CMAKE_BSV_COMPILER> --link <FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>"
    )
endif()

set(CMAKE_BSV_INFORMATION_LOADED 1)
