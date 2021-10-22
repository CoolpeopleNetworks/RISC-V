#
# FindRecycleBSVLib.cmake
#
# See: https://github.com/csail-csg/recycle-bsv-lib.git
#
# Output Variables:
#   RECYCLE_BSV_LIB_DIR  - Points to the location of the BSV files of Recycle-BSV-Lib.
#
include(FetchContent)

FetchContent_Declare(
    recycle_bsv_lib
    GIT_REPOSITORY https://github.com/csail-csg/recycle-bsv-lib.git
    GIT_TAG        "master"
)

FetchContent_MakeAvailable(recycle_bsv_lib)

FetchContent_GetProperties(recycle_bsv_lib SOURCE_DIR RECYCLE_BSV_DIR)

Find_File(RECYCLE_BSV_LIB_DIR 
    NAMES ClientServerUtil.bsv
    PATHS "${RECYCLE_BSV_DIR}" "${RECYCLE_BSV_DIR}/src/bsv"
    NO_DEFAULT_PATH,
    REQUIRED
)

get_filename_component(RECYCLE_BSV_LIB_DIR ${RECYCLE_BSV_LIB_DIR} DIRECTORY)

file(GLOB RECYCLE_BSV_LIB_SOURCES "${RECYCLE_BSV_LIB_DIR}/*.bsv")

add_library(RecycleBSVLib ${RECYCLE_BSV_LIB_SOURCES})

#add_library(recycle_bsv_lib INTERFACE)
#add_library(recycle_bsv_lib::recycle_bsv_lib ALIAS recycle_bsv_lib)
#set_property(TARGET recycle_bsv_lib PROPERTY INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}")
