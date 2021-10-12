import Common::*;
import ALU::*;

//
// EncodedInstruction
//
typedef union tagged {
    Word RawInstruction;

    struct {
        Bit#(7) opcode;
        Bit#(25) data;
    } Common;

    // RV32I - R-type
    struct {
        Bit#(7) opcode;
        RegisterIndex destination;
        Bit#(3) func3;
        RegisterIndex source1;
        RegisterIndex source2;
        Bit#(7) func7;
    } RtypeInstruction;

    // RV32I - I-type
    struct {
        Bit#(7) opcode;
        RegisterIndex destination;
        Bit#(3) func3;
        RegisterIndex source1;
        Bit#(12) immediate;
    } ItypeInstruction;

    // RV32I - S-type
    struct {
        Bit#(7) opcode;
        Bit#(5) immediateLow;
        Bit#(3) func3;
        RegisterIndex source1;
        RegisterIndex source2;
        Bit#(7) immediateHigh;
    } StypeInstruction;

    // RV32I - B-type
    struct {
        Bit#(7) opcode;
        Bit#(1) immediate11;
        Bit#(4) immediate4_1;
        Bit#(3) func3;
        RegisterIndex source1;
        RegisterIndex source2;
        Bit#(6) immediate10_5;
        Bit#(1) immediate12;
    } BtypeInstruction;

    // RV32I - U-type
    struct {
        Bit#(7) opcode;
        RegisterIndex destination;
        Bit#(20) immediate31_12;
    } UtypeInstruction;

    // RV32I - J-type
    struct {
        Bit#(7) opcode;
        RegisterIndex returnSave;
        Bit#(8) immediate19_12;
        Bit#(1) immediate11;
        Bit#(10) immediate10_1;
        Bit#(1) immediate20;
    } JtypeInstruction;
} EncodedInstruction deriving(Bits, Eq);

//
// ALUInstruction
//
typedef struct {
    RegisterIndex destination;
    ALUOperator  operator;
    Word immediate;
} ALUInstruction deriving(Bits, Eq);

//
// AUIPCInstruction
//
typedef struct {
    RegisterIndex destination;
    Word effectiveAddress;
} AUIPCInstruction deriving(Bits, Eq);

//
// BranchInstruction
//
typedef enum {
    BEQ,
    BNE,
    BLT,
    BLTU,
    BGE,
    BGEU,
    UNSUPPORTED_BRANCH_OPERATOR
} BranchOperator deriving(Bits, Eq);

typedef struct {
    BranchOperator operator;
    Bit#(13) offset;
} BranchInstruction deriving(Bits, Eq);

//
// JALInstruction
//
typedef struct {
    RegisterIndex destination;
    Bit#(21) offset;    // NOTE: always two byte aligned.
} JALInstruction deriving(Bits, Eq);

//
// JALRInstruction
//
typedef struct {
    RegisterIndex destination;
    Bit#(12) offset;    // NOTE: always two byte aligned.
} JALRInstruction deriving(Bits, Eq);

//
// LoadInstruction
//
typedef enum {
    LB,
    LH,
    LW,
    LBU,
    LHU,
    UNSUPPORTED_LOAD_OPERATOR
} LoadOperator deriving(Bits, Eq);

typedef struct {
    RegisterIndex destination;
    Bit#(12) offset;
    LoadOperator operator;
} LoadInstruction deriving(Bits, Eq);

//
// LUIInstruction
//
typedef AUIPCInstruction LUIInstruction;    // Same format as AUIPCInstruction.

//
// UnsupportedInstruction
//
typedef struct {} UnsupportedInstruction deriving(Bits, Eq);

//
// DecodedInstruction
//
typedef enum {
    LOAD,
    OPIMM,
    AUIPC,
    STORE,
    OP,
    LUI,
    BRANCH,
    JALR,
    JAL,
    UNSUPPORTED
} InstructionType deriving(Bits, Eq);

typedef struct {
    InstructionType instructionType;    
    RegisterIndex source1;
    RegisterIndex source2;
    
    union tagged {
        ALUInstruction ALUInstruction;
        AUIPCInstruction AUIPCInstruction;
        BranchInstruction BranchInstruction;
        JALInstruction JALInstruction;
        JALRInstruction JALRInstruction;
        LoadInstruction LoadInstruction;
        LUIInstruction LUIInstruction;
        UnsupportedInstruction UnsupportedInstruction;
    } specific;
} DecodedInstruction deriving(Bits, Eq);

//
// Executed Instruction
//
typedef struct {
    DecodedInstruction decodedInstruction;
    ProgramCounter nextPc;
} ExecutedInstruction deriving(Bits, Eq);
