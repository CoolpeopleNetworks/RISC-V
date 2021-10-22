include make/preamble.mk

dir	:= $(d)/Libraries
include	$(dir)/Rules.mk

dir	:= $(d)/RG-100
include	$(dir)/Rules.mk

include make/postscript.mk
