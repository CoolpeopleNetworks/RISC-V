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

// ================================================================
// Exports
export RG100Core (..), mkRG100Core;

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
module mkRG100Core#(
        ProgramCounter initialProgramCounter,
        InstructionMemory instructionMemory,
        DataMemory dataMemory,
        Word64 cLimit
)(RG100Core);
    //
    // Cycle Limit (Debugging)
    //
    Reg#(Word64) cycleLimit <- mkReg(cLimit);  // 0 = no limit

    //
    // CSR (Control and Status Register) file
    //
    RVCSRFile csrFile <- mkRVCSRFile();

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
    // Program counter forward from decode to fetch stage.
    //
    RWire#(ProgramCounter) programCounterForward <- mkRWire();

    //
    // Stage 1 - Instruction fetch
    //
    Reg#(ProgramCounter) fetchProgramCounter <- mkReg(initialProgramCounter);
    // This FIFO holds the program counter value for the instruction that's being
    // fetched.
    FIFO#(ProgramCounter) programCounterQueue <- mkPipelineFIFO();

    (* fire_when_enabled *)
    rule fetchInstruction;
        // Get the current program counter from the 'fetchProgramCounter' register, if the 
        // decode stage wants to override that value (due to a branch), read that 
        // from 'programCounterForward'.
        let programCounter = fetchProgramCounter;
        if (programCounterForward.wget() matches tagged Valid .programCounterOverride) begin
            $display("[%08d:%08x:fetch] forwarded PC = $%08x", csrFile.cycle_counter, programCounterOverride, programCounterOverride);
            programCounter = programCounterOverride;
        end

        $display("[%08d:%08x:fetch] fetching instruction", csrFile.cycle_counter, programCounter);

        // Perform memory request
        instructionMemory.request(programCounter);

        // Tell the decode stage what the program counter for the insruction it'll receive.
        programCounterQueue.enq(programCounter);

        // Point to the next instruction to fetch.  If the decode stage needs to override this
        // (due to a branch), the new PC will be forwarded here using 'programCounterForward'
        fetchProgramCounter <= programCounter + 4;
    endrule

    //
    // Stage 2 - Instruction Decode
    //
    InstructionDecoder instructionDecoder <- mkInstructionDecoder(registerFile, executionStageForward, memoryAccessStageForward);
    FIFO#(DecodedInstruction) decodedInstructionQueue <- mkFIFO1();

    (* fire_when_enabled *)
    rule decodeInstruction;
        let encodedInstruction = instructionMemory.first;
        let programCounter = programCounterQueue.first;

        $display("[%08d:%08x:decode] decoding instruction: %08x", csrFile.cycle_counter, programCounter, encodedInstruction);

        // Attempt to decode the instruction.  If register reads are blocked waiting
        // for data (memory reads), this will return tagged invalid (causing this stage to stall)
        let decodeResult = instructionDecoder.decode(programCounter, encodedInstruction);
        if (isValid(decodeResult)) begin
            instructionMemory.deq();
            programCounterQueue.deq();

            let decodedInstruction = fromMaybe(?, decodeResult);

            $display("[%08d:%08x:decode] next PC: %08x", csrFile.cycle_counter, programCounter, decodedInstruction.nextProgramCounter);

            // If the decoded instruction modified the next PC from what's expected,
            // communicate that to the fetch stage so it fetches the correct instruction.
            if (decodedInstruction.nextProgramCounter != programCounter + 4)
                programCounterForward.wset(decodedInstruction.nextProgramCounter);

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

        $display("[%08d:%08x:execute] executing instruction", csrFile.cycle_counter, decodedInstruction.programCounter);

        // Special case handling for specific SYSTEM instructions
        if (decodedInstruction.instructionType == SYSTEM) begin
            case(decodedInstruction.specific.SystemInstruction.operator)
                ECALL: begin
                    $display("[%08d:%08x:execute] ECALL instruction encountered - HALTED", csrFile.cycle_counter, decodedInstruction.programCounter);
                    $finish();
                end
                EBREAK: begin
                    $display("[%08d:%08x:execute] EBREAK instruction encountered - HALTED", csrFile.cycle_counter, decodedInstruction.programCounter);
                    $finish();
                end
            endcase
        end

        // let executedInstruction = executeDecodedInstruction(decodedInstruction);
        let executedInstruction =  instructionExecutor.execute(decodedInstruction);

        // Handle exceptions
        // !todo

        // If writeback data exists, that needs to be written into the previous pipeline 
        // stages using operand forwarding.
        if (executedInstruction.writeBack matches tagged Valid .wb) begin
            $display("[%08d:%08x:execute] complete (WB: x%d = %08x)", csrFile.cycle_counter, decodedInstruction.programCounter, wb.rd, wb.value);
            executionStageForward.wset(RVOperandForward{ 
                rd: wb.rd,
                value: tagged Valid wb.value
            });
        end else begin
            $display("[%08d:%08x:execute] complete", csrFile.cycle_counter, decodedInstruction.programCounter);
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
                // if (dataMemory.isLoadReady()) begin
                //     waitingForLoadToComplete <= False;
                //     $display("[%08d:%08x:memory] Load completed", csrFile.cycle_counter, executedInstruction.decodedInstruction.programCounter);

                //     let memoryResponse = dataMemory.first();
                //     dataMemory.deq();

                //     // Save the data that will be written back into the register file on the
                //     // writeback pipeline stage.
                //     executedInstruction.writeBack = tagged Valid Writeback {
                //         rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
                //         value: memoryResponse
                //     };

                //     // Forward the received data
                //     memoryAccessStageForward.wset(RVOperandForward{
                //         rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
                //         value: tagged Valid memoryResponse
                //     });

                //     executedInstructionQueue.deq();
                //     memoryAccessCompletedQueue.enq(executedInstruction);
                // end
            end else begin
                // NOTE: Alignment checks were already performed during the execution stage.
                // dataMemory.request(loadStore.effectiveAddress, loadStore.storeValue, loadStore.writeEnable);

                // if (loadStore.writeEnable == 0) begin
                //     $display("[%08d:%08x:memory] Executing LOAD", csrFile.cycle_counter, executedInstruction.decodedInstruction.programCounter);
                //     waitingForLoadToComplete <= True;
                // end else begin
                //     // Instruction was a store, no need to wait for a response.
                //     $display("[%08d:%08x:memory] Executing STORE", csrFile.cycle_counter, executedInstruction.decodedInstruction.programCounter);
                //     executedInstructionQueue.deq();
                //     memoryAccessCompletedQueue.enq(executedInstruction);
                // end
            end
        end else begin
            // Not a LOAD/STORE
            $display("[%08d:%08x:memory] not a load/store instruction", csrFile.cycle_counter, executedInstruction.decodedInstruction.programCounter);

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
            $display("[%08d:%08x:writeback] writing result ($%08x) to register x%d", csrFile.cycle_counter, memoryAccessCompleteInstruction.decodedInstruction.programCounter, wb.value, wb.rd);
            registerFile.write(wb.rd, wb.value);
        end else begin
            $display("[%08d:%08x:writeback] NO-OP", csrFile.cycle_counter, memoryAccessCompleteInstruction.decodedInstruction.programCounter);
        end

        csrFile.increment_instructions_retired_counter();
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        if (cycleLimit > 0 && csrFile.cycle_counter > cycleLimit) begin
            $display("[%08d] Cycle limit reached...exitting.", csrFile.cycle_counter);
            $finish();
        end

        csrFile.increment_cycle_counter();
    endrule
endmodule
