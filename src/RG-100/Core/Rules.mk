include make/preamble.mk

OBJS_$(d)  := ${BUILDDIR}/$(d)/ALU.bo					\
			  ${BUILDDIR}/$(d)/Common.bo				\
			  ${BUILDDIR}/$(d)/Core.bo					\
			  ${BUILDDIR}/$(d)/Instruction.bo			\
			  ${BUILDDIR}/$(d)/InstructionDecoder.bo	\
			  ${BUILDDIR}/$(d)/InstructionExecutor.bo	\
			  ${BUILDDIR}/$(d)/RegisterFile.bo

${BUILDDIR}/$(d)/CoreTest: $(OBJS_$(d))

TGTS_$(d)	:= ${BUILDDIR}/$(d)/CoreTest
TGT_BIN		:= $(TGT_BIN) $(TGTS_$(d))

include make/postscript.mk
