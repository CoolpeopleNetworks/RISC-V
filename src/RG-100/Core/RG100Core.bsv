import RVCSRFile::*;
import RVOperandForward::*;
import RVRegisterFile::*;
import RVTypes::*;

import Instruction::*;

// Core stages
import InstructionDecoder::*;
import InstructionExecutor::*;
import MemoryAccessor::*;
import RegisterWriteback::*;

import FIFO::*;
import SpecialFIFOs::*;
import Memory::*;
import MemUtil::*;
import Port::*;

typedef MemoryRequest#(32, 32) MemoryRequest32;
typedef MemoryResponse#(32) MemoryResponse32;

interface RG100Core;
endinterface

//
// Pipeline Stages
// 1. Instruction Fetch
//      - In this stage CPU reads instructions from memory address located in the Program Counter.
// 2. Instruction Decode
//      - In this stage, instruction is decoded and the register file accessed to get values from registers used in the instructin.
// 3. Instruction Execution
//      - In this stage, ALU operations are performed
// 4. Memory Access
//      - In this stage, memory operands are read/written that is present in the instruction.
// 5. Write Back
//      - In this stage, computed/fetched values are written back to the register file present in the instruction.
//
module mkCore#(
        ProgramCounter initialProgramCounter,
        ReadOnlyMemServerPort#(32, 2) instructionFetchPort,
        AtomicMemServerPort#(32, TLog#(TDiv#(32,8))) dataMemoryPort
)(RG100Core);
    //
    // Cycle counter
    //
    Reg#(Word) cycleCounter <- mkReg(0);

    //
    // Register file
    //
    RVRegisterFile registerFile <- mkRVRegisterFile();

    //
    // Operand forwarding between stages
    //
    RWire#(RVOperandForward) executionStageForward <- mkRWire();
    RWire#(RVOperandForward) memoryAccessStageForward <- mkRWire();

    //
    // Stages
    //

    // Stage 1 and 2 - Instruction fetch and decode
    FIFO#(DecodedInstruction) decodedInstructionQueue <- mkPipelineFIFO();
    InstructionDecoder instructionDecoder <- mkInstructionDecoder(
        cycleCounter,
        initialProgramCounter,
        instructionFetchPort,
        registerFile, 
        executionStageForward,
        memoryAccessStageForward,
        decodedInstructionQueue
    );

    // Stage 3 - Instruction execution
    FIFO#(ExecutedInstruction) executedInstructionQueue <- mkPipelineFIFO();
    InstructionExecutor instructionExecutor <- mkInstructionExecutor(
        cycleCounter,
        decodedInstructionQueue, 
        executionStageForward,
        executedInstructionQueue
    );

    // Stage 4 - Memory access
    FIFO#(ExecutedInstruction) memoryAccessCompletedQueue <- mkPipelineFIFO();
    MemoryAccessor memoryAccessor <- mkMemoryAccessor(
        cycleCounter,
        executedInstructionQueue, 
        dataMemoryPort, 
        memoryAccessStageForward,
        memoryAccessCompletedQueue
    );

    // Stage 5 - Register writeback
    RegisterWriteback registerWriteback <- mkRegisterWriteback(
        cycleCounter,
        memoryAccessCompletedQueue, 
        registerFile
    );

    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
        if (cycleCounter > 250) begin
            $finish();
        end
    endrule

endmodule
