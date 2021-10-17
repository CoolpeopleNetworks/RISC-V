# This file sets the basic flags for the BSV compiler
if(NOT CMAKE_BSV_COMPILE_OBJECT)
    set(CMAKE_BSV_COMPILE_OBJECT "<CMAKE_BSV_COMPILER> <SOURCE> <OBJECT>")
endif()
set(CMAKE_BSV_INFORMATION_LOADED 1)

include(CMakeBSVSupport)
