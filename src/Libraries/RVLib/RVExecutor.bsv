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
    LoadOperator operator;
} RVLoadRequest deriving(Bits, Eq, FShow);

typedef struct {
    Word effectiveAddress;
    StoreOperator operator;
} RVStoreRequest deriving(Bits, Eq, FShow);

typedef struct {
    ProgramCounter programCounter;

    Maybe#(ProgramCounter) changedProgramCounter;
    Maybe#(RVLoadRequest) loadRequest;
    Maybe#(RVStoreRequest) storeRequest;
    Maybe#(RVException) exception;
    Maybe#(RVWriteBack) writeBack;
} RVExecutedInstruction deriving(Bits, Eq, FShow);

interface RVExecutor
    method RVExecutedInstruction execute(RVDecodedInstruction decodedInstruction);
endinterface

module mkRVExecutor(RVExecutor);
    method RVExecutedInstruction execute(RVDecodedInstruction decodedInstruction);
    endmethod
endmodule