import RVInstruction::*;
import RVTypes::*;
import RVExceptions::*;

//
// DecodedInstruction
//
typedef enum {
    LOAD = 0,
    OPIMM = 1,
    AUIPC = 2,
    STORE = 3,
    OP = 4,
    LUI = 5,
    BRANCH = 6,
    JALR = 7,
    JAL = 8,
    SYSTEM = 9,
    UNSUPPORTED = 15
} InstructionType deriving(Bits, Eq);

typedef struct {
    ProgramCounter programCounter;
    ProgramCounter nextProgramCounter;  // counter *after* this instruction
    InstructionType instructionType;
    Word rs1;
    Word rs2;
    
    union tagged {
        ALUInstruction ALUInstruction;
        AUIPCInstruction AUIPCInstruction;
        BranchInstruction BranchInstruction;
        JALInstruction JALInstruction;
        JALRInstruction JALRInstruction;
        LoadInstruction LoadInstruction;
        LUIInstruction LUIInstruction;
        StoreInstruction StoreInstruction;
        SystemInstruction SystemInstruction;
        UnsupportedInstruction UnsupportedInstruction;
    } specific;
} DecodedInstruction deriving(Bits, Eq);

//
// Writeback
//
typedef struct {
    RegisterIndex rd;
    Word value;
} Writeback deriving(Bits, Eq);

typedef struct {
    Bit#(4) writeEnable;
    Word effectiveAddress;
    Word storeValue;
} LoadStore deriving(Bits, Eq);

typedef struct {
    RVExceptionCause exceptionCause;
    Word targetAddress;
} Exception deriving(Bits, Eq);

//
// Executed Instruction
//
typedef struct {
    DecodedInstruction decodedInstruction;
    Maybe#(Writeback) writeBack;
    Maybe#(LoadStore) loadStore;
    Maybe#(Exception) exception;
} ExecutedInstruction deriving(Bits, Eq);
