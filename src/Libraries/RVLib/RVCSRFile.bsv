import RVTypes::*;
import RegUtil::*;

typedef enum {
    Mstatus     = 'h300,    // Machine Status Register (MRW)
    Misa        = 'h301,    // Machine ISA and Extensions Register (MRW)
    Medeleg     = 'h302,    // Machine Exception Delegation Register (MRW)
    Mideleg     = 'h303,    // Machine Interrupt Delegation Register (MRW)
    Mie         = 'h304,    // Machine Interrupt Enable Register (MRW)
    Mtvec       = 'h305,    // (REQUIRED) Machine trap-handler base address (MRW)
    Mcounteren  = 'h306,    // Machine Counter Enable Register (MRW)

    Cycle       = 'hC00,    // Cycle counter for RDCYCLE instruction (URO)
    Time        = 'hC01,    // Timer for RDTIME instruction (URO)
    InstRet     = 'hC02,    // Instructions-retired counter for RDINSTRET instruction (URO)

    CycleH      = 'hC80,    // Upper 32 bits of cycle, RV32I only (URO)
    TimeH       = 'hC81,    // Upper 32 bits of time, RV32I only (URO)
    InstRetH    = 'hC82     // Upper 32 bits of instret, RV32I only (URO)    
} CSR deriving(Bits, Eq);

interface RVCSRFile;
    method Action increment_cycle_counter;
    method Action increment_instructions_retired_counter;
endinterface

module mkRVCSRFile(RVCSRFile);
    function Word getMisa();
        return 0;
    endfunction

    Reg#(Word64)    cycle_counter <- mkReg(0);
    Reg#(Word64)    time_counter <- mkReg(0);
    Reg#(Word64)    instructions_retired_counter <- mkReg(0);

    Reg#(Word)      mstatus <- mkReg(getMisa());
    Reg#(Word)      misa <- mkReadOnlyReg(0);

    Reg#(Word)      mcycle      = readOnlyReg(truncate(cycle_counter));
    Reg#(Word)      mtimer      = readOnlyReg(0);
    Reg#(Word)      minstret    = readOnlyReg(truncate(instructions_retired_counter));

    Reg#(Word)      mcycleh     = readOnlyReg(truncateLSB(cycle_counter));
    Reg#(Word)      mtimeh      = readOnlyReg(truncateLSB(time_counter));
    Reg#(Word)      minstreth   = readOnlyReg(truncateLSB(instructions_retired_counter));

    method Action increment_cycle_counter;
        cycle_counter <= cycle_counter + 1;
    endmethod

    method Action increment_instructions_retired_counter;
        instructions_retired_counter <= instructions_retired_counter + 1;
    endmethod
endmodule
