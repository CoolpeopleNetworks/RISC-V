import PGTypes::*;

import PipelineController::*;
import Exception::*;

//
// LoadRequest
//
// Structure containing information about a request to load data
// from memory.
//
typedef struct {
    RegisterIndex rd;
    Word effectiveAddress;
    RVLoadOperator operator;
} LoadRequest deriving(Bits, Eq, FShow);

//
// StoreRequest
//
// Structure containing information about a request to store data
// to memory.
//
typedef struct {
    Word wordAddress;               // XLEN aligned
    Bit#(TDiv#(XLEN, 8)) byteEnable;
    Word value;
} StoreRequest deriving(Bits, Eq, FShow);

//
// WriteBack
//
// Structure containing data to be written back to CPU registers
//
typedef struct {
    RegisterIndex rd;
    Word value;
} WriteBack deriving(Bits, Eq, FShow);

//
// ExecutedInstruction
//
// Structure describing an executed instruction including any resulting
// data.
//
typedef struct {
    // fetchIndex - Monotically increasing index of all instructions fetched.
    Word fetchIndex;

    // pipelineEpoch - Records which pipeline epoch corresponds to this instruction.
    PipelineEpoch pipelineEpoch;

    // programCounter - The program counter corresponding to this instruction.
    ProgramCounter programCounter;

    // changedProgramCounter - The next program counter if this instruction was a
    //                         jump/branch/etc.
    Maybe#(ProgramCounter) changedProgramCounter;

    // exception - The exception (if any) encounted during execution of the instruction.
    Maybe#(Exception) exception;

    // loadRequest - The load request (if any) of the executed instruction.
    Maybe#(LoadRequest) loadRequest;

    // storeRequest - The store request (if any) of the executed instruction.
    Maybe#(StoreRequest) storeRequest;

    // writeBack - The data to be written to the register file (if any) for the instruction.
    Maybe#(WriteBack) writeBack;
} ExecutedInstruction deriving(Bits, Eq, FShow);
