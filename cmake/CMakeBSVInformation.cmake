include(CMakeLanguageInformation)

# Load compiler-specific information.
if(CMAKE_BSV_COMPILER_ID)
  include(Compiler/${CMAKE_BSV_COMPILER_ID}-BSV)
endif()

include(CMakeCommonLanguageInclude)

if(NOT CMAKE_BSV_COMPILE_OBJECT)
    set(CMAKE_BSV_COMPILE_OBJECT 
        "<CMAKE_BSV_COMPILER> -t <TARGET> -o <OBJECT> <INCLUDES> <SOURCE>"
    )
endif()

if(NOT CMAKE_BSV_CREATE_STATIC_LIBRARY)
    set(CMAKE_BSV_CREATE_STATIC_LIBRARY
        "<CMAKE_BSV_COMPILER> --static-library -o <TARGET> <OBJECTS>" 
    )
endif()

if(NOT CMAKE_BSV_LINK_EXECUTABLE)
    set(CMAKE_BSV_LINK_EXECUTABLE 
    "<CMAKE_BSV_COMPILER> --link <OBJECTS> -o <TARGET> <LINK_LIBRARIES>"
    )
endif()

set(CMAKE_BSV_INFORMATION_LOADED 1)

function(add_bsim_testbench TARGET)
    add_test(NAME ${TARGET} COMMAND "${CMAKE_BSV_TESTWRAPPER}" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}")
endfunction()
