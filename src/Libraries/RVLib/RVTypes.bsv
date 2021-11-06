`ifdef RV64
typedef 64 XLEN;
`elsif RV128
typedef 128 XLEN
`else
`define RV32
typedef 32 XLEN;
`endif

typedef Bit#(XLEN) Word;
typedef Word ProgramCounter;
typedef Bit#(5) RegisterIndex;
