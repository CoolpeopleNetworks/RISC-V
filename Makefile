TOP:=$(shell pwd)
BUILDDIR:=$(TOP)/build

### Build tools
# 
BSC_INCLUDES    := "%/Libraries"
BSC             = $(shell which bsc)
COMPILE_BSV     = $(BSC) $(BSVF_ALL) $(BSVF_TGT) -p "$(BSC_INCLUDES):$(dir $<)" -u -bdir "${BUILDDIR}/$(dir $<)" $<

### Standard parts
#
include Rules.mk