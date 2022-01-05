import RVCSRFile::*;
import RVOperandForward::*;
import RVRegisterFile::*;
import RVTypes::*;

import Instruction::*;

// Core stages
import InstructionFetcher::*;
import InstructionDecoder::*;
import InstructionExecutor::*;
import MemoryAccessor::*;
import RegisterWriteback::*;

import GetPut::*;
import ClientServer::*;
import Memory::*;
import FIFOF::*;
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
        ReadOnlyMemServerPort#(32, 2) instructionFetchPort,
        AtomicMemServerPort#(32, TLog#(TDiv#(32,8))) dataMemory
)(RG100Core);
    //
    // Program counter
    //
    Reg#(ProgramCounter) programCounter <- mkReg(0);

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

    // Stage 1 - Instruction fetch
    FIFOF#(Tuple2#(ProgramCounter, Word32)) encodedInstructionQueue <- mkSizedFIFOF(1);
    InstructionFetcher instructionFetcher <- mkInstructionFetcher(
        programCounter, 
        instructionFetchPort, 
        encodedInstructionQueue
    );

    // Stage 2 - Instruction decode
    FIFOF#(DecodedInstruction) decodedInstructionQueue <- mkSizedFIFOF(1);
    InstructionDecoder instructionDecoder <- mkInstructionDecoder(
        encodedInstructionQueue, 
        registerFile, 
        executionStageForward,
        memoryAccessStageForward,
        decodedInstructionQueue,
        programCounter                  // <- modified for next instruction
    );

    // Stage 3 - Instruction execution
    FIFOF#(ExecutedInstruction) executedInstructionQueue <- mkSizedFIFOF(1);
    InstructionExecutor instructionExecutor <- mkInstructionExecutor(
        decodedInstructionQueue, 
        executionStageForward,
        executedInstructionQueue
    );

    // Stage 4 - Memory access
    FIFOF#(ExecutedInstruction) memoryAccessCompletedQueue <- mkSizedFIFOF(1);
    MemoryAccessor memoryAccessor <- mkMemoryAccessor(
        executedInstructionQueue, 
        dataMemory, 
        memoryAccessStageForward,
        memoryAccessCompletedQueue
    );

    // Stage 5 - Register writeback
    RegisterWriteback registerWriteback <- mkRegisterWriteback(
        memoryAccessCompletedQueue, 
        registerFile
    );

endmodule
