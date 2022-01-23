import RVTypes::*;
import RVALU::*;
import RVDecoder::*;
import RVExceptions::*;
import RVInstruction::*;
import RVCSRFile::*;

import Assert::*;

typedef struct {
    RegisterIndex rd;
    Word value;
} RVWriteBack deriving(Bits, Eq, FShow);

typedef struct {
    Word effectiveAddress;
    RVLoadOperator operator;
} RVLoadRequest deriving(Bits, Eq, FShow);

typedef struct {
    Word effectiveAddress;
    RVStoreOperator operator;
} RVStoreRequest deriving(Bits, Eq, FShow);

typedef struct {
    PipelineEpoch epoch;
    ProgramCounter programCounter;
    Maybe#(ProgramCounter) changedProgramCounter;
    Maybe#(RVLoadRequest) loadRequest;
    Maybe#(RVStoreRequest) storeRequest;
    Maybe#(RVException) exception;
    Maybe#(RVWriteBack) writeBack;
} RVExecutedInstruction deriving(Bits, Eq, FShow);

interface RVExecutor;
    method ActionValue#(RVExecutedInstruction) execute(RVDecodedInstruction decodedInstruction);
endinterface

module mkRVExecutor#(RVCSRFile csrFile)(RVExecutor);
    RVALU alu <- mkRVALU();

    function Bool isValidBranchOperator(RVBranchOperator operator);
        return (operator != pack(UNSUPPORTED_BRANCH_OPERATOR_010) &&
                operator != pack(UNSUPPORTED_BRANCH_OPERATOR_011)) ? True : False;
    endfunction

    function Bool isBranchTaken(RVDecodedInstruction decodedInstruction);
        // NOTE: Validity of the branch operator has already been checked.
        return case(decodedInstruction.branchOperator)
            pack(BEQ): return (decodedInstruction.rs1Value == decodedInstruction.rs2Value);
            pack(BNE): return (decodedInstruction.rs1Value != decodedInstruction.rs2Value);
            pack(BLT): return (signedLT(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            pack(BGE): return (signedGE(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            pack(BGEU): return (decodedInstruction.rs1Value >= decodedInstruction.rs2Value);
            pack(BLTU): return (decodedInstruction.rs1Value < decodedInstruction.rs2Value);
        endcase;
    endfunction

    function Bool isValidLoadOperator(RVLoadOperator loadOperator);
`ifdef RV32
        return (loadOperator != pack(UNSUPPORTED_LOAD_OPERATOR_011) &&
                loadOperator != pack(UNSUPPORTED_LOAD_OPERATOR_110) &&
                loadOperator != pack(UNSUPPORTED_LOAD_OPERATOR_111));
`elsif RV64
        return (loadOperator != pack(UNSUPPORTED_LOAD_OPERATOR_111));
`else
        return False;
`endif
    endfunction

    function Bool isValidStoreOperator(RVStoreOperator storeOperator);
`ifdef RV32
        return (storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_011) &&
                storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_100) &&
                storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_101) &&
                storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_110) &&
                storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_111));
`elsif RV64
        return (storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_100) &&
                storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_101) &&
                storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_110) &&
                storeOperator != pack(UNSUPPORTED_STORE_OPERATOR_111));
`else
        return False;
`endif
    endfunction

    function ProgramCounter getAdjustedProgramCounter(ProgramCounter programCounter, Word unsignedValue);
        Int#(XLEN) offset = unpack(unsignedValue);
        return pack(unpack(programCounter) + offset);
    endfunction

    method ActionValue#(RVExecutedInstruction) execute(RVDecodedInstruction decodedInstruction);
        let executedInstruction = RVExecutedInstruction {
            epoch: decodedInstruction.epoch,
            programCounter: decodedInstruction.programCounter,
            changedProgramCounter: tagged Invalid,
            loadRequest: tagged Invalid,
            storeRequest: tagged Invalid,
            exception: tagged Valid RVException {
                cause: ILLEGAL_INSTRUCTION
            },
            writeBack: tagged Invalid
        };

        case(decodedInstruction.opcode)
            ALU: begin
                dynamicAssert(isValid(decodedInstruction.rd), "ALU: rd is invalid");
                dynamicAssert(isValid(decodedInstruction.rs1), "ALU: rs1 is invalid");
                dynamicAssert(isValid(decodedInstruction.rs2) == False, "ALU: rs2 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.immediate) == False, "ALU: immediate SHOULD BE invalid");

                let result = alu.execute(
                    decodedInstruction.aluOperator, 
                    decodedInstruction.rs1Value,
                    fromMaybe(decodedInstruction.rs2Value, decodedInstruction.immediate)
                );

                if (isValid(result)) begin
                    executedInstruction.writeBack = tagged Valid RVWriteBack {
                        rd: fromMaybe(?, decodedInstruction.rd),
                        value: fromMaybe(?, result)
                    };
                    executedInstruction.exception = tagged Invalid;
                end
            end

            BRANCH: begin
                dynamicAssert(isValid(decodedInstruction.rd) == False, "BRANCH: rd SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.rs1), "BRANCH: rs1 is invalid");
                dynamicAssert(isValid(decodedInstruction.rs2) == False, "BRANCH: rs2 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.immediate), "BRANCH: immediate is invalid");

                if (isValidBranchOperator(decodedInstruction.branchOperator) &&
                    isValid(decodedInstruction.immediate)) begin
                    if (isBranchTaken(decodedInstruction)) begin
                        // Determine branch target address and check
                        // for address misalignment.
                        let branchTarget = getAdjustedProgramCounter(decodedInstruction.programCounter, fromMaybe(?, decodedInstruction.immediate));
                        // Branch target must be 32 bit aligned.
                        if (branchTarget[1:0] != 0) begin
                            executedInstruction.exception = tagged Valid RVException {
                                cause: INSTRUCTION_ADDRESS_MISALIGNED
                            };
                        end else begin
                            // Target address aligned
                            executedInstruction.changedProgramCounter = tagged Valid branchTarget;
                            executedInstruction.exception = tagged Invalid;
                        end
                    end else begin
                        executedInstruction.exception = tagged Invalid;
                    end
                end
            end

            COPY_IMMEDIATE: begin
                dynamicAssert(isValid(decodedInstruction.rd), "COPY_IMMEDIATE: rd is invalid");
                dynamicAssert(isValid(decodedInstruction.rs1) == False, "COPY_IMMEDIATE: rs1 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.rs2) == False, "COPY_IMMEDIATE: rs2 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.immediate), "COPY_IMMEDIATE: immediate is invalid");
                executedInstruction.writeBack = tagged Valid RVWriteBack {
                    rd: fromMaybe(?, decodedInstruction.rd),
                    value: fromMaybe(?, decodedInstruction.immediate)
                };
                executedInstruction.exception = tagged Invalid;
            end

            JUMP: begin
                dynamicAssert(isValid(decodedInstruction.rd), "JUMP: rd is invalid");
                dynamicAssert(isValid(decodedInstruction.rs1) == False, "JUMP: rs1 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP: rs2 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.immediate), "JUMP: immediate is invalid");
                
                let jumpTarget = getAdjustedProgramCounter(decodedInstruction.programCounter, fromMaybe(?, decodedInstruction.immediate));
                if (jumpTarget[1:0] != 0) begin
                    executedInstruction.exception = tagged Valid RVException {
                        cause: INSTRUCTION_ADDRESS_MISALIGNED
                    };
                end else begin
                    executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                    executedInstruction.writeBack = tagged Valid RVWriteBack {
                        rd: fromMaybe(?, decodedInstruction.rd),
                        value: (decodedInstruction.programCounter + 4)
                    };
                    executedInstruction.exception = tagged Invalid;
                end
            end

            JUMP_INDIRECT: begin
                dynamicAssert(isValid(decodedInstruction.rd), "JUMP_INDIRECT: rd is invalid");
                dynamicAssert(isValid(decodedInstruction.rs1), "JUMP_INDIRECT: rs1 is invalid");
                dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP_INDIRECT: rs2 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.immediate), "JUMP_INDIRECT: immediate is invalid");
                
                let jumpTarget = getAdjustedProgramCounter(decodedInstruction.rs1Value, fromMaybe(?, decodedInstruction.immediate));
                jumpTarget[0] = 0;

                if (jumpTarget[1:0] != 0) begin
                    executedInstruction.exception = tagged Valid RVException {
                        cause: INSTRUCTION_ADDRESS_MISALIGNED
                    };
                end else begin
                    executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                    executedInstruction.writeBack = tagged Valid RVWriteBack {
                        rd: fromMaybe(?, decodedInstruction.rd),
                        value: (decodedInstruction.programCounter + 4)
                    };
                    executedInstruction.exception = tagged Invalid;
                end

            end

            LOAD: begin
                // The actual memory request is handled in the Memory Access stage.
                dynamicAssert(isValid(decodedInstruction.rd), "LOAD: rd is invalid");
                dynamicAssert(isValid(decodedInstruction.rs1), "LOAD: rs1 is invalid");
                dynamicAssert(isValid(decodedInstruction.rs2) == False, "LOAD: rs2 SHOULD BE invalid");
                dynamicAssert(isValid(decodedInstruction.immediate), "LOAD: immediate is invalid");

                if (isValidLoadOperator(decodedInstruction.loadOperator)) begin
                    executedInstruction.exception = tagged Invalid;
                end
            end

            STORE: begin
                // The actual memory request is handled in the Memory Access stage.
                dynamicAssert(isValid(decodedInstruction.rd), "STORE: rd is invalid");
                dynamicAssert(isValid(decodedInstruction.rs1), "STORE: rs1 is invalid");
                dynamicAssert(isValid(decodedInstruction.rs2), "STORE: rs2 is invalid");
                dynamicAssert(isValid(decodedInstruction.immediate), "STORE: immediate is invalid");

                if (isValidStoreOperator(decodedInstruction.storeOperator)) begin
                    executedInstruction.exception = tagged Invalid;
                end
            end

            SYSTEM: begin
            end
        endcase

        return executedInstruction;
    endmethod
endmodule