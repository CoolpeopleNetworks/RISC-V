import RegUtil::*;

import RVTypes::*;

import MachineInformation::*;
import MachineStatus::*;
import MachineTraps::*;

typedef enum {
    MSTATUS         = 12'h300,    // Machine Status Register (MRW)
    MISA            = 12'h301,    // Machine ISA and Extensions Register (MRW)
    MEDELEG         = 12'h302,    // Machine Exception Delegation Register (MRW)
    MIDELEG         = 12'h303,    // Machine Interrupt Delegation Register (MRW)
    MIE             = 12'h304,    // Machine Interrupt Enable Register (MRW)
    MTVEC           = 12'h305,    // Machine trap-handler base address (MRW)
    MCOUNTEREN      = 12'h306,    // Machine Counter Enable Register (MRW)

    MCYCLE          = 12'hB00,    // Cycle counter for RDCYCLE instruction (MRW)
    MINSTRET        = 12'hB02,    // Machine instructions-retired counter (MRW)

    MHPMCOUNTER3    = 12'hB03,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER4    = 12'hB04,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER5    = 12'hB05,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER6    = 12'hB06,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER7    = 12'hB07,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER8    = 12'hB08,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER9    = 12'hB09,    // Machine performance-monitoring counter (MRW)

    MCYCLEH         = 12'hB80,    // Upper 32 bits of mcycle, RV32I only (MRW)
    MINSTRETH       = 12'hB82,    // Upper 32 bits of minstret, RV32I only (MRW)    

    MHPMCOUNTER3H   = 12'hB83,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER4H   = 12'hB84,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER5H   = 12'hB85,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER6H   = 12'hB86,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER7H   = 12'hB87,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER8H   = 12'hB88,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER9H   = 12'hB89,    // Machine performance-monitoring counter (upper 32 bits) (MRW)

    MVENDORID       = 12'hF11,    // Vendor ID (MRO)
    MARCHID         = 12'hF12,    // Architecture ID (MRO)
    MIMPID          = 12'hF13,    // Implementation ID (MRO)
    MHARTID         = 12'hF14,    // Hardware thread ID (MRO)
    MCONFIGPTR      = 12'hF15     // Pointer to configuration data structure (MRO)
} CSR deriving(Bits, Eq);

interface CSRFile;
    // Generic read/write support
    method Maybe#(Word) read(PrivilegeLevel curPriv, CSRIndex index);
    method ActionValue#(Bool) write(PrivilegeLevel curPriv, CSRIndex index, Word value);

    // Exception handling
    method ActionValue#(ProgramCounter) beginException(PrivilegeLevel privilegeLevel, RVExceptionCause exceptionCause);

    // Special purpose
    method Word64 cycle_counter;
    method Action increment_cycle_counter;
    method Word64 instructions_retired_counter;
    method Action increment_instructions_retired_counter;
endinterface

module mkCSRFile(CSRFile);

    MachineInformation machineInformation <- mkMachineInformationRegisters(0, 0, 0, 0, 0);
    MachineStatus machineStatus <- mkMachineStatusRegister();
    MachineTraps machineTraps <- mkMachineTrapRegisters();

    Reg#(Word64)    cycleCounter                <- mkReg(0);
    Reg#(Word64)    timeCounter                 <- mkReg(0);
    Reg#(Word64)    instructionsRetiredCounter  <- mkReg(0);

    Reg#(Word)      mcycle      = readOnlyReg(truncate(cycleCounter));
    Reg#(Word)      mtimer      = readOnlyReg(truncate(timeCounter));
    Reg#(Word)      minstret    = readOnlyReg(truncate(instructionsRetiredCounter));

    Reg#(Word)      mcycleh     = readOnlyReg(truncateLSB(cycleCounter));
    Reg#(Word)      mtimeh      = readOnlyReg(truncateLSB(timeCounter));
    Reg#(Word)      minstreth   = readOnlyReg(truncateLSB(instructionsRetiredCounter));

    method Maybe#(Word) read(PrivilegeLevel curPriv, CSRIndex index);
        // Access check
        if (pack(curPriv) < index[9:8]) begin
            return tagged Invalid;
        end else begin
            return case(unpack(index))
                // Machine Information Registers (MRO)
                MVENDORID:  tagged Valid machineInformation.mvendorid;
                MARCHID:    tagged Valid machineInformation.marchid;
                MIMPID:     tagged Valid machineInformation.mimpid;
                MHARTID:    tagged Valid machineInformation.mhartid;
                default:    tagged Invalid;
            endcase;
        end
    endmethod

    method ActionValue#(Bool) write(PrivilegeLevel curPriv, CSRIndex index, Word value);
        // Access and write to read-only CSR check.
        if (pack(curPriv) < index[9:8] || index[11:10] == 'b11) begin
            return False;
        end else begin
            return case(index)
                default: False;
            endcase;
        end
    endmethod

    method ActionValue#(ProgramCounter) beginException(PrivilegeLevel privilegeLevel, RVExceptionCause exceptionCause);
        return 'hdeadbeef;
    endmethod

    method Word64 cycle_counter;
        return cycleCounter;
    endmethod

    method Action increment_cycle_counter;
        cycleCounter <= cycleCounter + 1;
    endmethod

    method Word64 instructions_retired_counter;
        return instructionsRetiredCounter;
    endmethod
    
    method Action increment_instructions_retired_counter;
        instructionsRetiredCounter <= instructionsRetiredCounter + 1;
    endmethod
endmodule
