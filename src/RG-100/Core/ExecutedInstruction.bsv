import RVTypes::*;
import RVInstruction::*;
import RVExceptions::*;

typedef struct {
    RegisterIndex rd;
    Word value;
} WriteBack deriving(Bits, Eq, FShow);

typedef struct {
    Word effectiveAddress;
    RVLoadOperator operator;
} LoadRequest deriving(Bits, Eq, FShow);

typedef struct {
    Word effectiveAddress;
    RVStoreOperator operator;
} StoreRequest deriving(Bits, Eq, FShow);

typedef struct {
    PipelineEpoch epoch;
    ProgramCounter programCounter;
    Maybe#(ProgramCounter) changedProgramCounter;
    Maybe#(LoadRequest) loadRequest;
    Maybe#(StoreRequest) storeRequest;
    Maybe#(RVException) exception;
    Maybe#(WriteBack) writeBack;
} ExecutedInstruction deriving(Bits, Eq, FShow);
