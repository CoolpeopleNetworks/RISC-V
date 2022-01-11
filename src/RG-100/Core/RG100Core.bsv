import RVCSRFile::*;
import RVOperandForward::*;
import RVRegisterFile::*;
import RVTypes::*;

import Instruction::*;

// Core stages
import InstructionDecoder::*;
import InstructionExecutor::*;

import FIFO::*;
import SpecialFIFOs::*;

import InstructionMemory::*;
import DataMemory::*;

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
        InstructionMemory instructionMemory,
        DataMemory dataMemory
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

    // Interstage FIFOs
    FIFO#(DecodedInstruction) decodedInstructionQueue <- mkPipelineFIFO();
    FIFO#(ExecutedInstruction) executedInstructionQueue <- mkPipelineFIFO();
    FIFO#(ExecutedInstruction) memoryAccessCompletedQueue <- mkPipelineFIFO();

    // Stage 1 - Instruction fetch
    Reg#(ProgramCounter) lastFetchedProgramCounter <- mkReg('hFFFF);
    Reg#(ProgramCounter) programCounter <- mkReg(initialProgramCounter);

    rule fetchInstruction (programCounter != lastFetchedProgramCounter);
        $display("%d [fetch] Fetching instruction from $%08x", cycleCounter, programCounter);

        // Perform memory request
        instructionMemory.request(programCounter);
        lastFetchedProgramCounter <= programCounter;
    endrule

    // Stage 2 - Instruction Decode
    InstructionDecoder instructionDecoder <- mkInstructionDecoder(registerFile, executionStageForward, memoryAccessStageForward);
    rule decodeInstruction;
        let encodedInstruction = instructionMemory.first;
        let currentProgramCounter = programCounter;

        $display("%d [decode] decoding instruction at $%08x", cycleCounter, currentProgramCounter);

        // Attempt to decode the instruction.  If register reads are blocked waiting
        // for data (memory reads), this will return tagged invalid.
        let decodeResult = instructionDecoder.decode(currentProgramCounter, encodedInstruction);
        if (isValid(decodeResult)) begin
            instructionMemory.deq();
            let decodedInstruction = fromMaybe(?, decodeResult);
            programCounter <= decodedInstruction.nextProgramCounter;

            // Send the decode result to the output queue.
            decodedInstructionQueue.enq(decodedInstruction);
        end
    endrule

    // Stage 3 - Instruction execution
    InstructionExecutor instructionExecutor <- mkInstructionExecutor();
    rule executeInstruction;
        let decodedInstruction = decodedInstructionQueue.first();
        decodedInstructionQueue.deq();

        $display("%d [execute] executing instruction at $%08x", cycleCounter, decodedInstruction.programCounter);

        // Special case handling for specific SYSTEM instructions
        if (decodedInstruction.instructionType == SYSTEM) begin
            case(decodedInstruction.specific.SystemInstruction.operator)
                ECALL: begin
                    $display("%d [execute] ECALL instruction encountered at PC: %x - HALTED", cycleCounter, decodedInstruction.programCounter);
                    $finish();
                end
                EBREAK: begin
                    $display("%d [execute] EBREAK instruction encountered at PC: %x - HALTED", cycleCounter, decodedInstruction.programCounter);
                    $finish();
                end
            endcase
        end

        // let executedInstruction = executeDecodedInstruction(decodedInstruction);
        let executedInstruction =  instructionExecutor.execute(decodedInstruction);

        // Handle exceptions
        // !todo

        // If writeback data exists, that needs to be written into the previous pipeline 
        // stages using the register bypass.
        if (executedInstruction.writeBack matches tagged Valid .wb) begin
            executionStageForward.wset(RVOperandForward{ 
                rd: wb.rd,
                value: tagged Valid wb.value
            });
        end

        executedInstructionQueue.enq(executedInstruction);
    endrule

    // Stage 4 - Memory access
    Reg#(Bool) waitingForLoadToComplete <- mkReg(False);
    rule sendMemoryRequest;
        let executedInstruction = executedInstructionQueue.first();
        if(executedInstruction.loadStore matches tagged Valid .loadStore) begin
            // See if a load request has completed
            if (waitingForLoadToComplete) begin
                if (dataMemory.isLoadReady()) begin
                    waitingForLoadToComplete <= False;
                    $display("%d [memory] Load completed at $%08x", cycleCounter, executedInstruction.decodedInstruction.programCounter);

                    let memoryResponse = dataMemory.first();
                    dataMemory.deq();

                    // Save the data that will be written back into the register file on the
                    // writeback pipeline stage.
                    executedInstruction.writeBack = tagged Valid Writeback {
                        rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
                        value: memoryResponse
                    };

                    // Forward the received data
                    memoryAccessStageForward.wset(RVOperandForward{
                        rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
                        value: tagged Valid memoryResponse
                    });

                    executedInstructionQueue.deq();
                    memoryAccessCompletedQueue.enq(executedInstruction);
                end
            end else begin
                // NOTE: Alignment checks were already performed during the execution stage.
                dataMemory.request(loadStore.effectiveAddress, loadStore.storeValue, loadStore.writeEnable);

                if (loadStore.writeEnable == 0) begin
                    $display("%d [memory] Executing LOAD at $%08x", cycleCounter, executedInstruction.decodedInstruction.programCounter);
                    waitingForLoadToComplete <= True;
                end else begin
                    // Instruction was a store, no need to wait for a response.
                    $display("%d [memory] Executing STORE at $%08x", cycleCounter, executedInstruction.decodedInstruction.programCounter);
                    executedInstructionQueue.deq();
                    memoryAccessCompletedQueue.enq(executedInstruction);
                end
            end
        end else begin
            // Not a LOAD/STORE
            $display("%d [memory] Not a load/store instruction at $%08x", cycleCounter, executedInstruction.decodedInstruction.programCounter);

            executedInstructionQueue.deq();
            memoryAccessCompletedQueue.enq(executedInstruction);
        end
    endrule

    // Stage 5 - Register Writeback
    rule writeBack;
        let memoryAccessCompleteInstruction = memoryAccessCompletedQueue.first();
        memoryAccessCompletedQueue.deq();

        $display("%d [writeback] executing instruction at $%08x", cycleCounter, memoryAccessCompleteInstruction.decodedInstruction.programCounter);

        if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
            registerFile.write(wb.rd, wb.value);
        end
    endrule

    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
        if (cycleCounter > 250) begin
            $finish();
        end
    endrule

endmodule
