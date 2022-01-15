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
    method Word64 cycle_counter;
    method Action increment_cycle_counter;
    method Action increment_instructions_retired_counter;
endinterface

module mkRVCSRFile(RVCSRFile);
    function Word getMisa();
        return 0;
    endfunction

    Reg#(Word64)    cycleCounter <- mkReg(0);
    Reg#(Word64)    timeCounter <- mkReg(0);
    Reg#(Word64)    instructionsRetiredCounter <- mkReg(0);

    Reg#(Word)      mstatus <- mkRegU();
    Reg#(Word)      misa <- mkReadOnlyReg(getMisa());

    Reg#(Word)      mcycle      = readOnlyReg(truncate(cycleCounter));
    Reg#(Word)      mtimer      = readOnlyReg(truncate(timeCounter));
    Reg#(Word)      minstret    = readOnlyReg(truncate(instructionsRetiredCounter));

    Reg#(Word)      mcycleh     = readOnlyReg(truncateLSB(cycleCounter));
    Reg#(Word)      mtimeh      = readOnlyReg(truncateLSB(timeCounter));
    Reg#(Word)      minstreth   = readOnlyReg(truncateLSB(instructionsRetiredCounter));

    method Word64 cycle_counter;
        return cycleCounter;
    endmethod

    method Action increment_cycle_counter;
        cycleCounter <= cycleCounter + 1;
    endmethod

    method Action increment_instructions_retired_counter;
        instructionsRetiredCounter <= instructionsRetiredCounter + 1;
    endmethod
endmodule
