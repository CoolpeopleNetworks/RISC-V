import RVCSRFile::*;
import RVRegisterFile::*;
//import RVExecutor::*;
import RVExceptions::*;
import RVDecoder::*;
import RVTypes::*;
import RVInstruction::*;

import ProgramCounterRedirect::*;
import PipelineController::*;
import FetchUnit::*;
import DecodeUnit::*;
import ExecutionUnit::*;
import MemoryAccessUnit::*;
import WritebackUnit::*;

import Scoreboard::*;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Connectable::*;

import InstructionMemory::*;
import DataMemory::*;

// ================================================================
// Exports
export RG100Core (..), mkRG100Core;

interface RG100Core;
endinterface

typedef struct {
    PipelineEpoch epoch;
} FetchInfo deriving(Bits, Eq);

//
// Pipeline Stages
// 1. Instruction Fetch
//      - In this stage CPU reads instructions from memory address located in the Program Counter.
// 2. Instruction Decode
//      - In this stage, instruction is decoded and the register file accessed to get values from registers used in the instruction.
// 3. Instruction Execution
//      - In this stage, the decoded instruction is executed
// 4. Memory Access
//      - In this stage, memory operands are read/written that is present in the instruction.
// 5. Write Back
//      - In this stage, computed/fetched values are written back to the register file present in the instruction.
//
module mkRG100Core#(
        ProgramCounter initialProgramCounter,
        InstructionMemory instructionMemory,
        DataMemory dataMemory
)(RG100Core);
    //
    // Cycle counter
    //
    Reg#(Word64) cycleCounter <- mkReg(0);

    Reg#(Word64) cycleCounter <- mkReg(0);

    //
    // CPU Halt Flag
    //
    Reg#(Bool) halt <- mkReg(False);

    //
    // CSR (Control and Status Register) file
    //
    RVCSRFile csrFile <- mkRVCSRFile();

    //
    // Register file
    //
    RVRegisterFile registerFile <- mkRVRegisterFile();

    //
    // Scoreboard
    //
    Scoreboard#(4) scoreboard <- mkScoreboard;

    //
    // Pipeline stage epochs
    //
    PipelineController pipelineController <- mkPipelineController(6 /* stage count */);

    //
    // Current privilege level
    //
    Reg#(PrivilegeLevel) currentPrivilegeLevel <- mkReg(PRIVILEGE_LEVEL_MACHINE);

    Reg#(Bool) started <- mkReg(False);

    (* fire_when_enabled *)
    rule startup(started == False);
        $display("Cycle,Pipeline Epoch,Program Counter,Stage Number,Stage Name,Info");
        started <= True;
    endrule

    //
    // Stage 1 - Instruction fetch
    //
    ProgramCounterRedirect programCounterRedirect <- mkProgramCounterRedirect;
    Reg#(Bool) fetchEnabled <- mkReg(True);
    FetchUnit fetchUnit <- mkFetchUnit(
        cycleCounter,
        1,  // stage number
        initialProgramCounter,
        programCounterRedirect,
        instructionMemory,
        fetchEnabled
    );

    //
    // Stage 2 - Instruction Decode
    //
    DecodeUnit decodeUnit <- mkDecodeUnit(
        cycleCounter,
        2,  // stage number
        pipelineController,
        fetchUnit.getEncodedInstructionQueue,
        scoreboard,
        registerFile
    );

    //
    // Stage 3 - Instruction execution
    //
    ExecutionUnit executionUnit <- mkExecutionUnit(
        cycleCounter,
        3,  // stage number
        pipelineController,
        decodeUnit.getDecodedInstructionQueue,
        programCounterRedirect,
        scoreboard,
        csrFile,
        halt
    );

    //
    // Stage 4 - Memory access
    //
    MemoryAccessUnit memoryAccessUnit <- mkMemoryAccessUnit(
        cycleCounter,
        4,
        pipelineController,
        executionUnit.getExecutedInstructionQueue,
        dataMemory
    );

    // 
    // Stage 5 - Register Writeback
    //
    WritebackUnit writebackUnit <- mkWritebackUnit(
        cycleCounter,
        5,
        pipelineController,
        memoryAccessUnit.getMemoryAccessedInstructionQueue,
        programCounterRedirect,
        registerFile,
        csrFile,
        currentPrivilegeLevel
    );

`ifdef DISABLE_PIPELINING
    (* fire_when_enabled, no_implicit_conditions *)
    rule nonPipelinedMode;
        let wasRetired = writebackUnit.wasInstructionRetired;
        if (wasRetired) begin
            fetchEnabled <= True;
        end else begin
            fetchEnabled <= False;
        end
    endrule
`endif

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
        csrFile.increment_cycle_counter();
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule haltCheck;
        if (halt) begin
            $display("CPU HALTED. Cycles: %0d - Instructions retired: %0d", csrFile.cycle_counter, csrFile.instructions_retired_counter);
            $finish();
        end
    endrule
endmodule
