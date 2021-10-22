function(add_bluespec_simulation TARGET TOPMODULE)
    set(ARGNLIST ${ARGN})

    foreach(SIMDEP IN LISTS ARGNLIST)
        LIST(APPEND SIMDEPS ${CMAKE_CURRENT_BINARY_DIR}/${SIMDEP}.bo)

        # Get the path of the file and insert it into a list.   These
        # paths will be passed to the 'bsc' compiler.
        get_filename_component(TARGET_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${SIMDEP}" DIRECTORY)
        LIST(APPEND BSC_INCLUDE_DIR ${TARGET_PATH})	
    endforeach()

    LIST(APPEND BSC_INCLUDE_DIR "%/Libraries")

    LIST(REMOVE_DUPLICATES BSC_INCLUDE_DIR)
    LIST(JOIN BSC_INCLUDE_DIR ":" BSC_INCLUDE_DIR_STRING)

    # Create a build target for the file
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${TOPMODULE}.bo
        COMMAND ${CMAKE_BSV_COMPILER} -sim -u -p "${BSC_INCLUDE_DIR_STRING}" -bdir ${CMAKE_CURRENT_BINARY_DIR} -o ${CMAKE_CURRENT_BINARY_DIR}/${TOPMODULE}.bo ${TOPMODULE}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${SIMDEP}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim
        COMMAND ${CMAKE_BSV_COMPILER} -e ${TARGET} -sim -u -p "${BSC_INCLUDE_DIR_STRING}" -simdir ${CMAKE_CURRENT_BINARY_DIR} -bdir ${CMAKE_CURRENT_BINARY_DIR} -info-dir ${CMAKE_CURRENT_BINARY_DIR} -o ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${TOPMODULE}.bo
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} 
    )

    add_custom_target(${TARGET} ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim)
#    add_executable(${TARGET} ${TOP_MODULE} ${ARGNLIST})

    add_test(NAME ${TARGET} COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim)
endfunction()
