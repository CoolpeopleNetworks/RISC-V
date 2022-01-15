#
# FindBSCContrib.cmake
#
# See: https://github.com/B-Lang-org/bsc-contrib.git
#
# Output Variables:
#   BSC_CONTRIB_DIR  - Points to the location of the BSV files of bsc-contrib.
#
include(FetchContent)

FetchContent_Declare(
    bsc_contrib
    GIT_REPOSITORY https://github.com/B-Lang-org/bsc-contrib.git
    GIT_TAG        "main"
)

FetchContent_MakeAvailable(bsc_contrib)

FetchContent_GetProperties(bsc_contrib SOURCE_DIR BSC_CONTRIB_DIR)

# Default libraries
add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/Bus")
add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/FPGA/Misc")

# Parse components
foreach(_comp IN LISTS BSCContrib_FIND_COMPONENTS)
    if(_comp STREQUAL "XILINX")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/FPGA/Xilinx")
    endif()

    if(_comp STREQUAL "ALTERA")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/FPGA/Altera")
    endif()

    if(_comp STREQUAL "DDR2")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/FPGA/DDR2")
    endif()

    if(_comp STREQUAL "AMBA_TLM2")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM2/AHB")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM2/Axi")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM2/TLM")
    endif()

    if(_comp STREQUAL "AMBA_TLM3")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Ahb")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Apb")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Axi")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Axi4")
        add_bsv_module_dir("${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/TLM3")
    endif()
endforeach()
