function(add_bsim_testbench TARGET SOURCE)
    add_custom_target(
        ${TARGET} ALL
        DEPENDS ${ARGN}
        COMMAND bsc -show-schedule -sim -q -u -bdir "${CMAKE_CURRENT_BINARY_DIR}" -p "%/Libraries:${CMAKE_CURRENT_SOURCE_DIR}:${BSV_MODULE_DIRS}" -o "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}" "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE}"
        COMMAND bsc -sim -q -u -e mk${TARGET} -bdir "${CMAKE_CURRENT_BINARY_DIR}" -p "${CMAKE_CURRENT_SOURCE_DIR}:${BSV_MODULE_DIRS}" -o "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}"
    )

    add_test(NAME ${TARGET} COMMAND "${CMAKE_BSV_TESTWRAPPER}" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}")
endfunction()

function(add_bsv_module_dir BSV_MODULE_DIR)
    set(BSV_MODULE_DIRS "${BSV_MODULE_DIRS}:${BSV_MODULE_DIR}" CACHE STRING "" FORCE)
endfunction()

# Make sure the BSV_MODULE_DIRS cache is clear before running.
unset(BSV_MODULE_DIRS CACHE)