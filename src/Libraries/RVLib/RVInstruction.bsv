import RVTypes::*;
import RVALU::*;

typedef enum {
    ALU,
    BRANCH,
    COPY_IMMEDIATE, // copies immediate value to register rd (Used by LUI and AUIPC).
    JUMP,
    JUMP_INDIRECT,
    LOAD,
    STORE,
    SYSTEM,
    UNSUPPORTED_OPCODE
} RVOpcode deriving(Bits, Eq, FShow);

typedef Bit#(3) Func3;  // Corresponds to the func3 instruction field.

typedef Func3 RVBranchOperator;
typedef enum {
    BEQ  = 3'b000,
    BNE  = 3'b001,
    UNSUPPORTED_BRANCH_OPERATOR_010 = 3'b010,
    UNSUPPORTED_BRANCH_OPERATOR_011 = 3'b011,
    BLT  = 3'b100,
    BGE  = 3'b101,
    BLTU = 3'b110,
    BGEU = 3'b111
} RVBranchOperators deriving(Bits, Eq, FShow);

typedef Func3 RVLoadOperator;
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
} RVLoadOperators deriving(Bits, Eq, FShow);

typedef Func3 RVStoreOperator;
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
} RVStoreOperators deriving(Bits, Eq, FShow);

typedef Bit#(3) RVSystemOperator;
typedef enum {
    ECALL,
    EBREAK,
    SRET,
    MRET,
    WFI,
    UNSUPPORTED_SYSTEM_OPERATOR
} RVSystemOperators deriving(Bits, Eq, FShow);
