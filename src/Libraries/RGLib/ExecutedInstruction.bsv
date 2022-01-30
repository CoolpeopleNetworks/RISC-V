import RGTypes::*;
import PipelineController::*;

typedef struct {
    RegisterIndex rd;
    Word value;
} WriteBack deriving(Bits, Eq, FShow);

typedef struct {
    RegisterIndex rd;
    Word effectiveAddress;
    RVLoadOperator operator;
} LoadRequest deriving(Bits, Eq, FShow);

typedef struct {
    Word effectiveAddress;
    RVStoreOperator operator;
} StoreRequest deriving(Bits, Eq, FShow);

typedef struct {
    Bool isInterrupt;
    union tagged {
        RVExceptionCauses Exception;
        Bit#(TSub#(XLEN, 2)) Interrupt;
    } cause;
} Exception deriving(Bits, Eq, FShow);

typedef struct {
    Word fetchIndex;
    PipelineEpoch epoch;
    ProgramCounter programCounter;
    Maybe#(ProgramCounter) changedProgramCounter;
    Maybe#(LoadRequest) loadRequest;
    Maybe#(StoreRequest) storeRequest;
    Maybe#(Exception) exception;
    Maybe#(WriteBack) writeBack;
} ExecutedInstruction deriving(Bits, Eq, FShow);
