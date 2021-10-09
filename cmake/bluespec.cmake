find_program(BLUESPEC_BSC_EXECUTABLE NAMES "bsc")

function(add_bluespec_simulation TARGET TOPMODULE)
	set(ARGNLIST ${ARGN})

	foreach(SIMDEP IN LISTS ARGNLIST)
		LIST(APPEND SIMDEPS ${CMAKE_CURRENT_BINARY_DIR}/${SIMDEP}.bo)

		# Get the path of the file and insert it into a list.   These
		# paths will be passed to the 'bsc' compiler.
		get_filename_component(TARGET_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${SIMDEP}" DIRECTORY)
		LIST(APPEND TARGET_PATHS ${TARGET_PATH})	
	endforeach()

	LIST(REMOVE_DUPLICATES TARGET_PATHS)
	LIST(JOIN TARGET_PATHS ":" TARGET_PATHS_STRING)

			# Create a build target for the file
	add_custom_command(
		OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${TOPMODULE}.bo
		COMMAND ${BLUESPEC_BSC_EXECUTABLE} -sim -u -bdir ${CMAKE_CURRENT_BINARY_DIR} -o ${CMAKE_CURRENT_BINARY_DIR}/${TOPMODULE}.bo ${TOPMODULE}
		DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${SIMDEP}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	)
	
	add_custom_command(
		OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim
		COMMAND ${BLUESPEC_BSC_EXECUTABLE} -e ${TARGET} -sim -u -p "${TARGET_PATHS_STRING}" -simdir ${CMAKE_CURRENT_BINARY_DIR} -bdir ${CMAKE_CURRENT_BINARY_DIR} -info-dir ${CMAKE_CURRENT_BINARY_DIR} -o ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim
		DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${TOPMODULE}.bo
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	)

	add_custom_target(${TARGET} ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim)

	add_test(NAME ${TARGET} COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_bsim)
endfunction()

# function(add_bluespec_verilog_package TARGET TOPMODULE)
# set(ARGNLIST ${ARGN})
# 	foreach(SIMDEP IN LISTS ARGNLIST)
# 		LIST(APPEND SIMDEPS ${CMAKE_CURRENT_BINARY_DIR}/verilog/${SIMDEP}.bo)

# 		# Get the path of the file and insert it into a list.   These
# 		# paths will be passed to the 'bsc' compiler.
# 		get_filename_component(TARGET_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${SIMDEP}" DIRECTORY)
# 		LIST(APPEND TARGET_PATHS ${TARGET_PATH})	
# 	endforeach()

# 	LIST(REMOVE_DUPLICATES TARGET_PATHS)
# 	LIST(JOIN TARGET_PATHS ":" TARGET_PATHS_STRING)

# 	file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/verilog)

# 	# Create a build target for the file
# 	add_custom_command(
# 		OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/verilog/${TOPMODULE}.bo
# 		COMMAND ${BLUESPEC_BSC_EXECUTABLE} -u -verilog -vdir ${CMAKE_CURRENT_BINARY_DIR}/verilog -bdir ${CMAKE_CURRENT_BINARY_DIR}/verilog -o ${CMAKE_CURRENT_BINARY_DIR}/verilog/${TOPMODULE}.bo ${TOPMODULE}
# 		DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${SIMDEP}
# 		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
# 	)

# 	add_custom_command(
# 		OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/verilog/${TARGET}.v
# 		COMMAND ${BLUESPEC_BSC_EXECUTABLE} -e ${TARGET} -verilog -u -p "${TARGET_PATHS_STRING}" -vdir ${CMAKE_CURRENT_BINARY_DIR}/verilog -bdir ${CMAKE_CURRENT_BINARY_DIR}/verilog -info-dir ${CMAKE_CURRENT_BINARY_DIR}/verilog -o ${CMAKE_CURRENT_BINARY_DIR}/verilog/${TARGET}.v
# 		DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/verilog/${TOPMODULE}.bo
# 		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
# 	)

# 	add_custom_target(${TARGET} ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/verilog/${TARGET}.v)
# endfunction()