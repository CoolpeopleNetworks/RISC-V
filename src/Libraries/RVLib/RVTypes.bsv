`ifdef RV64
typedef 64 XLEN;
`elsif RV128
typedef 128 XLEN
`else
`define RV32
typedef 32 XLEN;
`endif

typedef Bit#(XLEN) Word;
typedef Bit#(32) Word32;
typedef Bit#(64) Word64;
typedef Bit#(128) Word128;

typedef Bit#(XLEN) UnsignedInt;
typedef Int#(XLEN) SignedInt;

typedef Word ProgramCounter;
typedef Bit#(5) RegisterIndex;

typedef TLog#(TDiv#(n,8)) DataSz#(numeric type n);
