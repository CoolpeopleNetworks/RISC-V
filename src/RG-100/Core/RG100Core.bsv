import RVCSRFile::*;
import RVOperandForward::*;
import RVRegisterFile::*;
import RVTypes::*;
import RVInstruction::*;

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

    //
    // Stage 1 - Instruction fetch
    //
    Reg#(ProgramCounter) lastFetchedProgramCounter <- mkReg('hFFFF);
    Reg#(ProgramCounter) programCounter <- mkReg(initialProgramCounter);

    rule fetchInstruction (programCounter != lastFetchedProgramCounter);
        $display("[%08d:%08x:fetch] Fetching instruction", cycleCounter, programCounter);

        // Perform memory request
        instructionMemory.request(programCounter);
        lastFetchedProgramCounter <= programCounter;
    endrule

    //
    // Stage 2 - Instruction Decode
    //
    InstructionDecoder instructionDecoder <- mkInstructionDecoder(registerFile, executionStageForward, memoryAccessStageForward);
    FIFO#(DecodedInstruction) decodedInstructionQueue <- mkFIFO1();

    (* fire_when_enabled *)
    rule decodeInstruction;
        let encodedInstruction = instructionMemory.first;
        let currentProgramCounter = programCounter;

        $display("[%08d:%08x:decode] decoding instruction", cycleCounter, currentProgramCounter);

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

    //
    // Stage 3 - Instruction execution
    //
    InstructionExecutor instructionExecutor <- mkInstructionExecutor();
    FIFO#(ExecutedInstruction) executedInstructionQueue <- mkFIFO1();

    (* fire_when_enabled *)
    rule executeInstruction;
        let decodedInstruction = decodedInstructionQueue.first();
        decodedInstructionQueue.deq();

        $display("[%08d:%08x:execute] executing instruction", cycleCounter, decodedInstruction.programCounter);

        // Special case handling for specific SYSTEM instructions
        if (decodedInstruction.instructionType == SYSTEM) begin
            case(decodedInstruction.specific.SystemInstruction.operator)
                ECALL: begin
                    $display("[%08d:%08x:execute] ECALL instruction encountered - HALTED", cycleCounter, decodedInstruction.programCounter);
                    $finish();
                end
                EBREAK: begin
                    $display("[%08d:%08x:execute] EBREAK instruction encountered - HALTED", cycleCounter, decodedInstruction.programCounter);
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

    //
    // Stage 4 - Memory access
    //
    Reg#(Bool) waitingForLoadToComplete <- mkReg(False);
    FIFO#(ExecutedInstruction) memoryAccessCompletedQueue <- mkFIFO1();

    (* fire_when_enabled *)
    rule memoryAccess;
        let executedInstruction = executedInstructionQueue.first();
        if(executedInstruction.loadStore matches tagged Valid .loadStore) begin
            // See if a load request has completed
            if (waitingForLoadToComplete) begin
                if (dataMemory.isLoadReady()) begin
                    waitingForLoadToComplete <= False;
                    $display("[%08d:%08x:memory] Load completed", cycleCounter, executedInstruction.decodedInstruction.programCounter);

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
                    $display("[%08d:%08x:memory] Executing LOAD", cycleCounter, executedInstruction.decodedInstruction.programCounter);
                    waitingForLoadToComplete <= True;
                end else begin
                    // Instruction was a store, no need to wait for a response.
                    $display("[%08d:%08x:memory] Executing STORE", cycleCounter, executedInstruction.decodedInstruction.programCounter);
                    executedInstructionQueue.deq();
                    memoryAccessCompletedQueue.enq(executedInstruction);
                end
            end
        end else begin
            // Not a LOAD/STORE
            $display("[%08d:%08x:memory] Not a load/store instruction", cycleCounter, executedInstruction.decodedInstruction.programCounter);

            executedInstructionQueue.deq();
            memoryAccessCompletedQueue.enq(executedInstruction);
        end
    endrule

    // Stage 5 - Register Writeback
    (* fire_when_enabled *)
    rule writeBack;
        let memoryAccessCompleteInstruction = memoryAccessCompletedQueue.first();
        memoryAccessCompletedQueue.deq();

        if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
            $display("[%08d:%08x:writeback] writing result (%08d) to register r%d", cycleCounter, memoryAccessCompleteInstruction.decodedInstruction.programCounter, wb.value, wb.rd);
            registerFile.write(wb.rd, wb.value);
        end else begin
            $display("[%08d:%08x:writeback] NO-OP", cycleCounter, memoryAccessCompleteInstruction.decodedInstruction.programCounter);
        end
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
        if (cycleCounter > 250) begin
            $finish();
        end
    endrule

endmodule
