import RVTypes::*;

typedef enum {
    Mstatus     = 'h300,    // Machine Status Register (MRW)
    Misa        = 'h301,    // Machine ISA and Extensions Register (MRW)
    Medeleg     = 'h302,    // Machine Exception Delegation Register (MRW)
    Mideleg     = 'h303,    // Machine Interrupt Delegation Register (MRW)
    Mie         = 'h304,    // Machine Interrupt Enable Register (MRW)
    Mtvec       = 'h305,    // (REQUIRED) Machine Interrupt Disable Register (MRW)
    Mcounteren  = 'h306,    // Machine Counter Enable Register (MRW)

    Cycle       = 'hC00,    // Cycle counter for RDCYCLE instruction (URO)
    Time        = 'hC01,    // Timer for RDTIME instruction (URO)
    InstRet     = 'hC02,    // Instructions-retired counter for RDINSTRET instruction (URO)

    CycleH      = 'hC80,    // Upper 32 bits of cycle, RV32I only (URO)
    TimeH       = 'hC81,    // Upper 32 bits of time, RV32I only (URO)
    InstRetH    = 'hC82     // Upper 32 bits of instret, RV32I only (URO)    
} CSRIndex deriving(Bits, Eq);
