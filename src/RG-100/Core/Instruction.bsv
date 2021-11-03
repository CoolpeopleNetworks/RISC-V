import Common::*;
import ALU::*;

//
// EncodedInstructions
//

// RV32I - R-type
typedef struct {
    Bit#(7) func7;
    RegisterIndex source2;
    RegisterIndex source1;
    Bit#(3) func3;
    RegisterIndex destination;
    Bit#(7) opcode;
} RtypeInstruction deriving(Bits, Eq);

// RV32I - I-type
typedef struct {
    Bit#(12) immediate;
    RegisterIndex source1;
    Bit#(3) func3;
    RegisterIndex destination;
    Bit#(7) opcode;
} ItypeInstruction deriving(Bits, Eq);

// RV32I - S-type
typedef struct {
    Bit#(7) immediate11_5;
    RegisterIndex source2;
    RegisterIndex source1;
    Bit#(3) func3;
    Bit#(5) immediate4_0;
    Bit#(7) opcode;
} StypeInstruction deriving(Bits, Eq);

// RV32I - B-type
typedef struct {
    Bit#(1) immediate12;
    Bit#(6) immediate10_5;
    RegisterIndex source2;
    RegisterIndex source1;
    Bit#(3) func3;
    Bit#(4) immediate4_1;
    Bit#(1) immediate11;
    Bit#(7) opcode;
} BtypeInstruction deriving(Bits, Eq);

// RV32I - U-type
typedef struct {
    Bit#(20) immediate31_12;
    RegisterIndex destination;
    Bit#(7) opcode;
} UtypeInstruction deriving(Bits, Eq);

// RV32I - J-type
typedef struct {
    Bit#(1) immediate20;
    Bit#(10) immediate10_1;
    Bit#(1) immediate11;
    Bit#(8) immediate19_12;
    RegisterIndex returnSave;
    Bit#(7) opcode;
} JtypeInstruction deriving(Bits, Eq);

//
// ALUInstruction
//
typedef struct {
    RegisterIndex destination;
    ALUOperator  operator;
    Bit#(12) immediate;
} ALUInstruction deriving(Bits, Eq);

//
// AUIPCInstruction
//
typedef struct {
    RegisterIndex destination;
    Word offset;
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
typedef struct {
    RegisterIndex destination;
    Bit#(20) immediate;
} LUIInstruction deriving(Bits, Eq);

//
// StoreInstruction
//
typedef enum {
    SB,
    SH,
    SW,
    UNSUPPORTED_STORE_OPERATOR
} StoreOperator deriving(Bits, Eq);

typedef struct {
    Bit#(12) offset;
    StoreOperator operator;
} StoreInstruction deriving(Bits, Eq);

//
// SystemInstruction
//
typedef enum {
    ECALL,
    EBREAK,
    UNSUPPORTED_SYSTEM_OPERATOR
} SystemOperator deriving(Bits, Eq);

typedef struct {
    SystemOperator operator;
} SystemInstruction deriving(Bits, Eq);

//
// UnsupportedInstruction
//
typedef struct {} UnsupportedInstruction deriving(Bits, Eq);

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
        StoreInstruction StoreInstruction;
        SystemInstruction SystemInstruction;
        UnsupportedInstruction UnsupportedInstruction;
    } specific;
} DecodedInstruction deriving(Bits, Eq);

//
// Executed Instruction
//
typedef struct {
    DecodedInstruction decodedInstruction;
    ProgramCounter nextPc;
    RegisterIndex writeBack;
    Word writeBackData;

    // LOAD/Store specific data
    Word effectiveAddress;
    Bool misaligned;        // If True, LOAD/STORE instruction request address was misaligned.
    Bit#(4) byteMask;
} ExecutedInstruction deriving(Bits, Eq);
