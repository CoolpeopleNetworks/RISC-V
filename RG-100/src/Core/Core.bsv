import ALU::*;
import Common::*;
import Instruction::*;

import InstructionDecoder::*;
//import InstructionExecution::*;

import RegisterFile::*;

import GetPut::*;
import ClientServer::*;
import Memory::*;
import FIFOF::*;

typedef MemoryRequest#(32, 32) MemoryRequest32;
typedef MemoryResponse#(32) MemoryResponse32;

interface Core;
    interface MemoryClient#(32, 32) instructionMemoryClient;
    interface MemoryClient#(32, 32) dataMemoryClient;
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
(* synthesize *)
module mkCore(Core);

    //
    // Program Counter
    //
    Reg#(ProgramCounter)        pc <- mkReg(0);

    //
    // Register File
    //
    RegisterFile                registerFile <- mkRegisterFile();

    //
    // Data request/response FIFOs.
    //
    FIFOF#(MemoryRequest32)     dataMemoryRequests <- mkFIFOF;
    FIFOF#(MemoryResponse32)    dataMemoryResponses <- mkFIFOF;

    //
    // Stage FIFOs
    //
    FIFOF#(MemoryRequest32)     instructionMemoryRequests <- mkFIFOF;
    FIFOF#(MemoryResponse32)    instructionMemoryResponses <- mkFIFOF;
    FIFOF#(DecodedInstruction)  decodedInstructions <- mkFIFOF;
    FIFOF#(ExecutedInstruction) memoryAccessInstructions <- mkFIFOF;
    FIFOF#(ExecutedInstruction) writeBackInstructions <- mkFIFOF;

    //
    // Stage 1. Instruction Fetch
    //      - In this stage CPU reads instructions from memory address located in the Program Counter.
    //
    Reg#(ProgramCounter)        fetchPC <- mkReg('hFFFFFFFF);

    rule stage1(fetchPC != pc);
        instructionMemoryRequests.enq(MemoryRequest32 {
            data: ?,
            address: pc,
            byteen: 'hF,
            write: False
        });
        fetchPC <= pc;
    endrule

    //
    // Stage 2. Instruction Decode
    //      - In this stage, instruction is decoded and the register file accessed to get values from registers used in the instructin.
    //
    rule stage2;
        let encodedInstruction = instructionMemoryResponses.first();
        instructionMemoryResponses.deq();

        let decodedInstruction = InstructionDecoder::decode(encodedInstruction.data);
        decodedInstructions.enq(decodedInstruction);
    endrule

    //
    // Stage 3. Instruction Execution
    //      - In this stage, ALU operations are performed
    //
    rule stage3;
        let decodedInstruction = decodedInstructions.first();
        decodedInstructions.deq();

        let r1 = registerFile.read1(decodedInstruction.source1);
        let r2 = registerFile.read2(decodedInstruction.source2);

//        let executedInstruction = executeDecodedInstruction(decodedInstruction, pc, r1, r2);

//        memoryAccessInstructions.enq(executedInstruction);
    endrule

    //
    // Stage 4. Memory Access
    //      - In this stage, memory operands are read/written that is present in the instruction.
    //
    // rule stage4;
    //     let executedInstruction = memoryAccessInstructions.first();
    //     memoryAccessInstructions.deq();

    //     if (executedInstruction.instructionType == LOAD) begin
    //         // Put a request into the data bus
    //         dataMemoryRequests.enq(MemoryRequest32 {
    //             data: ?,
    //             address: 0, // BUGBUG: get load store destination
    //             byteen: 'hF,
    //             write: False
    //         });
    //     end else if (executedInstruction.instructionType == STORE) begin
    //     end

    //     writeBackInstructions.enq(executedInstruction);
    // endrule

    //
    // Stage 5. Write Back
    //      - In this stage, computed/fetched values are written back to the register file present in the instruction.
    //
    // rule stage5;
    //     let executedInstruction = writeBackInstructions.first();
    //     writeBackInstructions.deq();

    //     if (executedInstruction.instructionType == LOAD) begin
    //     end else if (executedInstruction.instructionType == STORE) begin
    //     end else begin
    //     end
    // endrule

    //
    // instructionMemoryClient
    //
    interface MemoryClient instructionMemoryClient;
        interface Put response;
            method Action put(MemoryResponse32 a);
                instructionMemoryResponses.enq(a);
            endmethod
        endinterface
        interface Get request;
            method ActionValue#(MemoryRequest32) get;
                instructionMemoryRequests.deq;
                return instructionMemoryRequests.first;
            endmethod
        endinterface
    endinterface

    //
    // dataMemoryClient
    //
    interface MemoryClient dataMemoryClient;
        interface Put response;
            method Action put(MemoryResponse32 a);
                dataMemoryResponses.enq(a);
            endmethod
        endinterface
        interface Get request;
            method ActionValue#(MemoryRequest32) get;
                dataMemoryRequests.deq;
                return dataMemoryRequests.first;
            endmethod
        endinterface
    endinterface
endmodule
