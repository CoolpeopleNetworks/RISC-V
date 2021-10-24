# This file sets the basic flags for the BSV compiler
set(CMAKE_BSV_FLAGS_INIT "$ENV{BSVFLAGS} ${CMAKE_BSV_FLAGS_INIT} -bdir ${CMAKE_CURRENT_BINARY_DIR} -simdir ${CMAKE_CURRENT_BINARY_DIR} -info-dir ${CMAKE_CURRENT_BINARY_DIR}")
set(CMAKE_INCLUDE_FLAG_BSV "-I ")

cmake_initialize_per_config_variable(CMAKE_BSV_FLAGS "Flags used by the BSV compiler")
