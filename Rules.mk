# Standard things
.SUFFIXES:
.SUFFIXES:	.bsv .bo .ba

all: targets

# Subdirectories
dir	:= src
include		$(dir)/Rules.mk

# General directory independent rules
$(BUILDDIR)/%.bo: %.bsv
	@mkdir -p ${BUILDDIR}/$(dir $<)
	@$(COMPILE_BSV)

# The variables TGT_*, CLEAN and CMD_INST* may be added to by the Makefile
# fragments in the various subdirectories.
$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

.PHONY:		targets
targets:	$(BUILDDIR) $(TGT_BIN)

.PHONY:		clean
clean:
	@rm -rf $(BUILDDIR)
