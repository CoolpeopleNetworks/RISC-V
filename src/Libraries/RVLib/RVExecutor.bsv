import RVTypes::*;
import RVALU::*;
import RVDecoder::*;
import RVExceptions::*;
import RVInstruction::*;

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
    method RVExecutedInstruction execute(RVDecodedInstruction decodedInstruction);
endinterface

module mkRVExecutor(RVExecutor);
    method RVExecutedInstruction execute(RVDecodedInstruction decodedInstruction);
        let executedInstruction = RVExecutedInstruction {
            epoch: ?,
            programCounter: decodedInstruction.programCounter,
            changedProgramCounter: tagged Invalid,
            loadRequest: tagged Invalid,
            storeRequest: tagged Invalid,
            exception: tagged Invalid,
            writeBack: tagged Invalid
        };

        case(decodedInstruction.opcode)
            default: begin
                executedInstruction.exception = tagged Valid RVException {
                    cause: ILLEGAL_INSTRUCTION
                };
            end
        endcase

        return executedInstruction;
    endmethod
endmodule