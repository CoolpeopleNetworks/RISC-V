import Common::*;
import Instruction::*;

import InstructionDecoder::*;
import InstructionExecutor::*;

import RegisterFile::*;

import GetPut::*;
import ClientServer::*;
import Memory::*;
import FIFOF::*;

typedef MemoryRequest#(32, 32) MemoryRequest32;
typedef MemoryResponse#(32) MemoryResponse32;

interface Core;
    method Action enableTracing();
    
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
typedef enum {
    RESET,
    RUNNING
} State deriving(Bits, Eq);

(* synthesize *)
module mkCore(Core);
    //
    // State
    //
    Reg#(State)                 state <- mkReg(RESET);

    //
    // Program Counter
    //
    Reg#(ProgramCounter)        pc <- mkReg(0);

    //
    // Register File
    //
    RegisterFile                registerFile <- mkRegisterFile();

    //
    // Instruction Decoder
    //
    InstructionDecoder          instructionDecoder <- mkInstructionDecoder();

    //
    // Instruction Executor
    //
    InstructionExecutor         instructionExecutor <- mkInstructionExecutor();

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
    // Tracing
    //
    Reg#(Bool)                  trace <- mkReg(True);

    //
    // Startup
    //
    rule startup(state == RESET);
        state <= RUNNING;
    endrule

    //
    // Stage 1. Instruction Fetch
    //      - In this stage CPU reads instructions from memory address located in the Program Counter.
    //
    Reg#(ProgramCounter)        fetchPC <- mkReg('hFFFFFFFF);

    rule stage1(state == RUNNING && fetchPC != pc);
        if (trace) begin
            $display("[stage1] Loading instruction at PC: %h", pc);
        end

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
    rule stage2(state == RUNNING);
        let encodedInstruction = instructionMemoryResponses.first();
        instructionMemoryResponses.deq();

        if (trace) begin
            $display("[stage1] Decoding instruction (%h) at PC: %h", encodedInstruction.data, pc);
        end

        let decodedInstruction = instructionDecoder.decode(encodedInstruction.data);
        decodedInstructions.enq(decodedInstruction);

        if (decodedInstruction.instructionType == UNSUPPORTED) begin
            $display("[stage1] ERROR - Unsupported instruction at PC: %h", pc);
            $fatal();
        end
    endrule

    //
    // Stage 3. Instruction Execution
    //      - In this stage, ALU operations are performed
    //
    rule stage3(state == RUNNING);
        let decodedInstruction = decodedInstructions.first();
        decodedInstructions.deq();

        let r1 = registerFile.read1(decodedInstruction.source1);
        let r2 = registerFile.read2(decodedInstruction.source2);

        let executedInstruction = instructionExecutor.executeDecodedInstruction(decodedInstruction, pc, r1, r2);

        // Special case handling for SYSTEM
        if (executedInstruction.decodedInstruction.instructionType == SYSTEM) begin
            case(executedInstruction.decodedInstruction.specific.SystemInstruction.operator)
                ECALL: begin
                    $display("[stage3] ECALL instruction encountered at PC: %x - HALTED", pc);
                    $finish();
                end
                EBREAK: begin
                    $display("[stage3] EBREAK instruction encountered at PC: %x - HALTED", pc);
                    $finish();
                end
            endcase
        end

        // Special case handling for LOAD/STORE
        if (executedInstruction.decodedInstruction.instructionType == LOAD) begin
            if (executedInstruction.misaligned) begin
                $display("[stage3] ERROR - Misaligned LOAD at PC: %h", pc);
                $fatal();
            end
            memoryAccessInstructions.enq(executedInstruction);

            // Request the data from memory.
            dataMemoryRequests.enq(MemoryRequest32 {
                data: ?,
                address: executedInstruction.effectiveAddress, 
                byteen: 0,
                write: False
            });
        end else if (executedInstruction.decodedInstruction.instructionType == STORE) begin
        end else begin
        end

    endrule

    //
    // Stage 4. Memory Access
    //      - In this stage, memory operands are read/written that is present in the instruction.    
    rule stage4(state == RUNNING);
        let executedInstruction = memoryAccessInstructions.first();
        memoryAccessInstructions.deq();

        if (executedInstruction.decodedInstruction.instructionType == LOAD) begin
            let memoryResponse = dataMemoryResponses.first();
            dataMemoryResponses.deq();

            executedInstruction.writeBack = executedInstruction.decodedInstruction.specific.LoadInstruction.destination;
            executedInstruction.writeBackData = memoryResponse.data;

        end else if (executedInstruction.decodedInstruction.instructionType == STORE) begin
        end

        writeBackInstructions.enq(executedInstruction);
    endrule

    //
    // Stage 5. Write Back
    //      - In this stage, computed/fetched values are written back to the register file present in the instruction.
    rule stage5(state == RUNNING);
        let executedInstruction = writeBackInstructions.first();
        writeBackInstructions.deq();

        registerFile.write(executedInstruction.writeBack, executedInstruction.writeBackData);
    endrule

    method Action enableTracing();
        trace <= True;
    endmethod

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
