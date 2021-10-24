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

set(RECYCLE_BSV_LIB_SOURCES
    ${RECYCLE_BSV_DIR}/src/bsv/ClientServerUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/ClockGate.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/CompareProvisos.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/ConcatReg.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/Ehr.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/FIFOG.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/GenericAtomicMem.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/MemUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/OneWriteReg.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/PerfMonitor.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/PerfMonitor.defines
    ${RECYCLE_BSV_DIR}/src/bsv/PerfMonitorConnectal.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/PolymorphicMem.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/Port.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/PortUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/PrintTrace.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/RWBram.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/RegFileUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/RegUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/SRAMCore.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/SRAMUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/SafeCounter.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/ScheduleMonitor.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/SearchFIFO.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/ServerUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/ShiftRegister.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/StmtFSMExtra.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/StmtFSMUtil.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/StringUtils.bsv
    ${RECYCLE_BSV_DIR}/src/bsv/VerilogEHR.bsv
)

add_library(RecycleBSVLib STATIC ${RECYCLE_BSV_LIB_SOURCES})
add_library(RecycleBSVLib::RecycleBSVLib ALIAS RecycleBSVLib)

target_include_directories(RecycleBSVLib PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}RecycleBSVLib${CMAKE_STATIC_LIBRARY_SUFFIX}")
