import RVBypass::*;
import RVCSRFile::*;
import RVRegisterFile::*;
import RVTypes::*;

import BypassedRegisterFile::*;
import Instruction::*;
import InstructionFetcher::*;
import InstructionDecoder::*;
import InstructionExecutor::*;

import GetPut::*;
import ClientServer::*;
import Memory::*;
import FIFOF::*;

import MemUtil::*;
import Port::*;

typedef MemoryRequest#(32, 32) MemoryRequest32;
typedef MemoryResponse#(32) MemoryResponse32;

interface Core;
    method Action enableTracing();
endinterface

//
// Pipeline Stages (NOT CURRENTLY IMPLEMENTED)
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
    )(Core);

    //
    // Status Registers
    //
    RVCSRFile                   csrFile <- mkRVCSRFile();

    //
    // Program Counter
    //
    Reg#(ProgramCounter)        programCounter <- mkReg(0);

    //
    // Register File
    //
    let bypassA = RVBypass{
        state: BYPASS_STATE_EMPTY,
        rd: ?,
        value: ?
    };

    let bypassB = RVBypass{
        state: BYPASS_STATE_EMPTY,
        rd: ?,
        value: ?
    };
    RVRegisterFile              registerFile <- mkBypassedRegisterFile(bypassA, bypassB);

    //
    // Stages
    //

    // Stage 1 - Instruction Fetch
    FIFOF#(Word32)              encodedInstructionQueue <- mkFIFOF();
    InstructionFetcher          instructionFetcher <- mkInstructionFetcher(programCounter, instructionFetchPort, encodedInstructionQueue);

    // Stage 2 - Instruction Decode
    FIFOF#(DecodedInstruction)  decodedInstructionQueue <- mkFIFOF();
    InstructionDecoder          instructionDecoder <- mkInstructionDecoder(encodedInstructionQueue, decodedInstructionQueue);

    // Stage 3 - Instruction Execution
    FIFOF#(ExecutedInstruction) executedInstructionQueue <- mkFIFOF();
    InstructionExecutor         instructionExecutor <- mkInstructionExecutor(programCounter, registerFile, decodedInstructionQueue, executedInstructionQueue);

    //
    // Tracing
    //
    Reg#(Bool)                  trace <- mkReg(True);

    //
    // Startup
    //
    // rule execute;
    //     //
    //     // Fetch - Read instruction from memory address located in the Program Counter.
    //     //
    //     instructionFetchPort.request.enq(ReadOnlyMemReq{ addr: pc });
    //     let encodedInstruction = instructionFetchPort.response.first();
    //     instructionFetchPort.response.deq();

    //     if (trace) begin
    //         $display("[stage1] Decoding instruction (%h) at PC: %h", encodedInstruction.data, pc);
    //     end

    //     //
    //     // Decode - Instruction is decoded and the register file accessed to get values from registers used in the instruction.
    //     //
    //     let decodedInstruction = instructionDecoder.decode(encodedInstruction.data);
    //     if (decodedInstruction.instructionType == UNSUPPORTED) begin
    //         $display("[stage1] ERROR - Unsupported instruction at PC: %h", pc);
    //         $fatal();
    //     end

    //     let rs1 = registerFile.read1(decodedInstruction.rs1);
    //     let rs2 = registerFile.read2(decodedInstruction.rs2);

    //     //
    //     // Execute - ALU operations are performed
    //     //
    //     let executedInstruction = instructionExecutor.executeDecodedInstruction(decodedInstruction, pc, rs1, rs2);

    //     // Special case handling for SYSTEM
    //     if (executedInstruction.decodedInstruction.instructionType == SYSTEM) begin
    //         case(executedInstruction.decodedInstruction.specific.SystemInstruction.operator)
    //             ECALL: begin
    //                 $display("[stage3] ECALL instruction encountered at PC: %x - HALTED", pc);
    //                 $finish();
    //             end
    //             EBREAK: begin
    //                 $display("[stage3] EBREAK instruction encountered at PC: %x - HALTED", pc);
    //                 $finish();
    //             end
    //         endcase
    //     end

    //     //
    //     // Memory Access - Memory operands are read/written that are present in the instruction.
    //     //
    //     if ((executedInstruction.decodedInstruction.instructionType == LOAD) ||
    //         (executedInstruction.decodedInstruction.instructionType == STORE)) begin
    //         if (executedInstruction.misaligned) begin
    //             $display("[stage3] ERROR - Misaligned LOAD/STORE at PC: %h", pc);
    //             $fatal();
    //         end

    //         let addr = executedInstruction.effectiveAddress;
    //         Word alignedData = rs2 << {addr[1:0], 3'b0};
    //         Bit#(4) writeEnable = (executedInstruction.decodedInstruction.instructionType == LOAD ? 0 : 
    //             case(executedInstruction.decodedInstruction.specific.StoreInstruction.operator)
    //                 SB: ('b0001 << addr[1:0]);
    //                 SH: ('b0011 << addr[1:0]);
    //                 SW: ('b1111);
    //             endcase);

    //         dataMemory.request.enq(AtomicMemReq {
    //                     write_en: writeEnable,
    //                     atomic_op: None,
    //                     addr: executedInstruction.effectiveAddress,
    //                     data: alignedData} );
    //     end

    //     if (executedInstruction.decodedInstruction.instructionType == LOAD) begin
    //         let memoryResponse = dataMemory.response.first();
    //         dataMemory.response.deq();

    //         executedInstruction.writeBack = executedInstruction.decodedInstruction.specific.LoadInstruction.rd;
    //         executedInstruction.writeBackData = memoryResponse.data;
    //     end

    //     //
    //     // Write Back - Computed/fetched values are written back to the register file present in the instruction.
    //     //
    //     registerFile.write(executedInstruction.writeBack, executedInstruction.writeBackData);

    // endrule

    method Action enableTracing();
        trace <= True;
    endmethod
endmodule
