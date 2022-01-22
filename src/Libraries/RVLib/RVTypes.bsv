`ifdef RV64
typedef 64 XLEN;
`elsif RV128
typedef 128 XLEN
`else
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
typedef Bit#(12) CSRIndex;

typedef TLog#(TDiv#(n,8)) DataSz#(numeric type n);

typedef enum {
    PRIVILEGE_LEVEL_USER        = 2'b00,
    PRIVILEGE_LEVEL_SUPERVISOR  = 2'b01,
    PRIVILEGE_LEVEL_HYPERVISOR  = 2'b10,
    PRIVILEGE_LEVEL_MACHINE     = 2'b11
} PrivilegeLevel deriving(Bits, Eq);

typedef Word PipelineEpoch;
