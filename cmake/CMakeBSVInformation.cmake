include(CMakeLanguageInformation)

# Load compiler-specific information.
if(CMAKE_BSV_COMPILER_ID)
  include(Compiler/${CMAKE_BSV_COMPILER_ID}-BSV)
endif()

include(CMakeCommonLanguageInclude)

# Create a renobj.cmake script that renames foo.bsv.bo to foo.bo.
# This is done so the BSC compiler can properlhy find packages.
# Note: this functionality is used below in the CMAKE_BSV_COMPILE_OBJECT variable.
FILE(WRITE ${CMAKE_BINARY_DIR}/renobj.cmake "
    GET_FILENAME_COMPONENT(NAME \${FILE} NAME)
    STRING(REGEX REPLACE \"\\\\.bsv\\\\.bo\\$\" \".bo\" LINK \${FILE})
    EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E create_symlink \${NAME} \${LINK})
")

if(NOT CMAKE_BSV_COMPILE_OBJECT)
    set(CMAKE_BSV_COMPILE_OBJECT 
        "<CMAKE_BSV_COMPILER> -u -bdir ${CMAKE_CURRENT_BINARY_DIR} <DEFINES> <INCLUDES> -o <OBJECT> <SOURCE>"
#        "${CMAKE_COMMAND} -DFILE=<OBJECT> -P ${CMAKE_BINARY_DIR}/renobj.cmake"
    )
endif()

if(NOT CMAKE_BSV_CREATE_STATIC_LIBRARY)
    set(CMAKE_BSV_CREATE_STATIC_LIBRARY "CRAP -o <TARGET> <OBJECTS>")
endif()

if(NOT CMAKE_BSV_LINK_EXECUTABLE)
    set(CMAKE_BSV_LINK_EXECUTABLE "<CMAKE_BSV_COMPILER> -u <FLAGS> <CMAKE_BSV_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
endif()

set(CMAKE_BSV_INFORMATION_LOADED 1)

include(CMakeBSVSupport)
