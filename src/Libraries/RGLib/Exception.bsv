import RGTypes::*;

//
// Exception
//
// Structure containing information about an exceptional condition
// encounted by the processor.
typedef struct {
    Bool isInterrupt;
    union tagged {
        RVExceptionCauses Exception;
        Bit#(TSub#(XLEN, 2)) Interrupt;
    } cause;
} Exception deriving(Bits, Eq, FShow);
