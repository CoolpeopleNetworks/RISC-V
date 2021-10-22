include make/preamble.mk

dir	:= $(d)/Caching
include	$(dir)/Rules.mk

dir	:= $(d)/TileLink
include	$(dir)/Rules.mk

# RecycleBSVLib
$(BUILDDIR)/$(d)/recycle-bsv-lib:
	git clone https://github.com/csail-csg/recycle-bsv-lib.git $@

TGT_BIN := $(TGT_BIN) $(BUILDDIR)/$(d)/recycle-bsv-lib

include make/postscript.mk
