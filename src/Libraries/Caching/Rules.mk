include make/preamble.mk

OBJS_$(d)  := $(d)/Cache.bo				\
			  $(d)/CacheArrayUnit.bo 	\
			  $(d)/DirectMappedCache.bo

include make/postscript.mk
