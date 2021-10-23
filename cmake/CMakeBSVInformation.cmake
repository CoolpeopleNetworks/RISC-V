include(CMakeLanguageInformation)

# Load compiler-specific information.
if(CMAKE_BSV_COMPILER_ID)
  include(Compiler/${CMAKE_BSV_COMPILER_ID}-BSV)
endif()

include(CMakeCommonLanguageInclude)

if(NOT CMAKE_BSV_COMPILE_OBJECT)
    set(CMAKE_BSV_COMPILE_OBJECT 
        "<CMAKE_BSV_COMPILER> -o <OBJECT> -i <SOURCE>"
    )
endif()

if(NOT CMAKE_BSV_CREATE_STATIC_LIBRARY)
    # BSC doesn't have a notion of static libraries.  They are simulated
    # for cmake by creating a directory name <foo>.a and copying the 
    # obj files there.
    set(CMAKE_BSV_CREATE_STATIC_LIBRARY
        "${CMAKE_COMMAND} -E make_directory <TARGET>" 
        # "${CMAKE_COMMAND} -E copy <OBJECTS> <TARGET>"
    )
endif()

if(NOT CMAKE_BSV_LINK_EXECUTABLE)
    set(CMAKE_BSV_LINK_EXECUTABLE "<CMAKE_BSV_COMPILER> -u <FLAGS> <CMAKE_BSV_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
endif()

set(CMAKE_BSV_INFORMATION_LOADED 1)

include(CMakeBSVSupport)
