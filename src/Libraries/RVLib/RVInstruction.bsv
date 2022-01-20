import RVTypes::*;
import RVALU::*;

typedef enum {
    LOAD,
    STORE,
    COPY_IMMEDIATE, // copies immediate value to register rd (Used by LUI and AUIPC).
    BRANCH,
    JUMP,
    JUMP_INDIRECT,
    ALU,
    SYSTEM,
    UNSUPPORTED_OPCODE
} RVOpcode deriving(Bits, Eq, FShow);

typedef enum {
    BEQ  = 3'b000,
    BNE  = 3'b001,
    UNSUPPORTED_BRANCH_OPERATOR_010 = 3'b010,
    UNSUPPORTED_BRANCH_OPERATOR_011 = 3'b011,
    BLT  = 3'b100,
    BGE  = 3'b101,
    BLTU = 3'b110,
    BGEU = 3'b111
} RVBranchOperator deriving(Bits, Eq, FShow);

typedef enum {
    LB  = 3'b000,
    LH  = 3'b001,
    LW  = 3'b010,
`ifdef RV32
    UNSUPPORTED_LOAD_OPERATOR_011 = 3'b011,
`elsif RV64
    LD = 3'b011,
`endif
    LBU = 3'b100,
    LHU = 3'b101,
`ifdef RV32
    UNSUPPORTED_LOAD_OPERATOR_110 = 3'b110,
`elsif RV64
    LWU = 3'b110,
`endif
    UNSUPPORTED_LOAD_OPERATOR_111 = 3'b111
} RVLoadOperator deriving(Bits, Eq, FShow);

typedef enum {
    SB  = 3'b000,
    SH  = 3'b001,
    SW  = 3'b010,
`ifdef RV32
    UNSUPPORTED_STORE_OPERATOR_011 = 3'b011,
`elsif RV64
    SD = 3'b011,
`endif
    UNSUPPORTED_STORE_OPERATOR_100 = 3'b100,
    UNSUPPORTED_STORE_OPERATOR_101 = 3'b101,
    UNSUPPORTED_STORE_OPERATOR_110 = 3'b110,
    UNSUPPORTED_STORE_OPERATOR_111 = 3'b111
} RVStoreOperator deriving(Bits, Eq, FShow);

typedef enum {
    ECALL,
    EBREAK,
    SRET,
    MRET,
    WFI,
    UNSUPPORTED_SYSTEM_OPERATOR
} RVSystemOperators deriving(Bits, Eq, FShow);

typedef Bit#(3) RVSystemOperator;

//
// EncodedInstructions
//

// RV32I - R-type
typedef struct {
    Bit#(7) func7;
    RegisterIndex rs2;
    RegisterIndex rs1;
    Bit#(3) func3;
    RegisterIndex rd;
    Bit#(7) opcode;
} RtypeInstruction deriving(Bits, Eq);

// RV32I - I-type
typedef struct {
    Bit#(12) immediate;
    RegisterIndex rs1;
    Bit#(3) func3;
    RegisterIndex rd;
    Bit#(7) opcode;
} ItypeInstruction deriving(Bits, Eq);

// RV32I - S-type
typedef struct {
    Bit#(7) immediate11_5;
    RegisterIndex rs2;
    RegisterIndex rs1;
    Bit#(3) func3;
    Bit#(5) immediate4_0;
    Bit#(7) opcode;
} StypeInstruction deriving(Bits, Eq);

// RV32I - B-type
typedef struct {
    Bit#(1) immediate12;
    Bit#(6) immediate10_5;
    RegisterIndex rs2;
    RegisterIndex rs1;
    Bit#(3) func3;
    Bit#(4) immediate4_1;
    Bit#(1) immediate11;
    Bit#(7) opcode;
} BtypeInstruction deriving(Bits, Eq);

// RV32I - U-type
typedef struct {
    Bit#(20) immediate31_12;
    RegisterIndex rd;
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
    RegisterIndex rd;
    RVALUOperator  operator;
    Bit#(12) immediate;
} ALUInstruction deriving(Bits, Eq);

//
// AUIPCInstruction
//
typedef struct {
    RegisterIndex rd;
    Word offset;
} AUIPCInstruction deriving(Bits, Eq);

//
// BranchInstruction
//
typedef struct {
    RVBranchOperator operator;
    Bit#(13) offset;
} BranchInstruction deriving(Bits, Eq);

//
// JALInstruction
//
typedef struct {
    RegisterIndex rd;
    Bit#(21) offset;    // NOTE: always two byte aligned.
} JALInstruction deriving(Bits, Eq);

//
// JALRInstruction
//
typedef struct {
    RegisterIndex rd;
    Bit#(12) offset;    // NOTE: always two byte aligned.
} JALRInstruction deriving(Bits, Eq);

//
// LoadInstruction
//
typedef struct {
    RegisterIndex rd;
    Bit#(12) offset;
    RVLoadOperator operator;
} LoadInstruction deriving(Bits, Eq);

//
// LUIInstruction
//
typedef struct {
    RegisterIndex rd;
    Bit#(20) immediate;
} LUIInstruction deriving(Bits, Eq);

//
// StoreInstruction
//
typedef struct {
    Bit#(12) offset;
    RVStoreOperator operator;
} StoreInstruction deriving(Bits, Eq);

//
// SystemInstruction
//
typedef struct {
    RegisterIndex rd;
    RVSystemOperator operator;
} SystemInstruction deriving(Bits, Eq);

//
// UnsupportedInstruction
//
typedef struct {} UnsupportedInstruction deriving(Bits, Eq);
