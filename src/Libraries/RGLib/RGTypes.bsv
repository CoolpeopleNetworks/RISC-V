import RVTypes::*;
import Memory::*;

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

export Memory::*, RVTypes::*, RGTypes::*;
