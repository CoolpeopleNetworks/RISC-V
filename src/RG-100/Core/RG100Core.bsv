import RVCSRFile::*;
import RVRegisterFile::*;
import RVExecutor::*;
import RVExceptions::*;
import RVDecoder::*;
import RVTypes::*;
import RVInstruction::*;

import Scoreboard::*;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

import InstructionMemory::*;
import DataMemory::*;

// ================================================================
// Exports
export RG100Core (..), mkRG100Core;

interface RG100Core;
endinterface

typedef struct {
    ProgramCounter programCounter;
    PipelineEpoch epoch;
} FetchInfo deriving(Bits, Eq);

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
    // Scoreboard
    //
    Scoreboard#(4) scoreboard <- mkScoreboard;

    //
    // Current privilege level
    //
    Reg#(PrivilegeLevel) currentPrivilegeLevel <- mkReg(PRIVILEGE_LEVEL_MACHINE);

    //
    // Stage 1 - Instruction fetch
    //
    Reg#(ProgramCounter) fetchProgramCounter <- mkReg(initialProgramCounter);
    Reg#(PipelineEpoch) fetchEpoch <- mkReg(0);
    RWire#(ProgramCounter) programCounterRedirect <- mkRWire();

    // This FIFO holds the program counter value for the instruction that's being
    // fetched.
    FIFO#(FetchInfo) fetchInfoQueue <- mkPipelineFIFO();

    (* fire_when_enabled *)
    rule fetchInstruction;
        // Get the current program counter from the 'fetchProgramCounter' register, if the 
        // program counter redirect has a value, move that into the program counter and
        // increment the epoch.
        let currentEpoch = fetchEpoch;
        let programCounter = fetchProgramCounter;
        if (programCounterRedirect.wget() matches tagged Valid .programCounterRedirect) begin
            programCounter = programCounterRedirect;

            $display("[%08d:%08x:fetch] redirected PC = $%08x", csrFile.cycle_counter, programCounter, programCounter);
            currentEpoch = fetchEpoch + 1;
            fetchEpoch <= currentEpoch;
        end

        $display("[%08d:%08x:fetch] fetching instruction", csrFile.cycle_counter, programCounter);

        // Perform memory request
        instructionMemory.request(programCounter);

        // Tell the decode stage what the program counter for the insruction it'll receive.
        fetchInfoQueue.enq(FetchInfo {
            programCounter: programCounter,
            epoch: currentEpoch
        });

        // Point to the next instruction to fetch.  If the decode stage needs to override this
        // (due to a branch), the new PC will be forwarded here using 'programCounterForward'
        fetchProgramCounter <= programCounter + 4;
    endrule

    //
    // Stage 2 - Instruction Decode
    //
    RVDecoder decoder <- mkRVDecoder;
    Reg#(PipelineEpoch) decoderEpoch <- mkReg(0);
    FIFO#(RVDecodedInstruction) decodedInstructionQueue <- mkFIFO1();

    (* fire_when_enabled *)
    rule decodeInstruction;
        let encodedInstruction = instructionMemory.first;
        if (fetchInfoQueue.first().epoch < decoderEpoch) begin
            // Epoch mismatch, ignore the decode request.
            instructionMemory.deq();
            fetchInfoQueue.deq();
        end else begin
            let programCounter = fetchInfoQueue.first.programCounter;
            let decodedInstruction = decoder.decode(programCounter, encodedInstruction);
            let stallWaitingForOperands = scoreboard.search(decodedInstruction.rs1, decodedInstruction.rs2);
            if (stallWaitingForOperands) begin
                $display("[%08d:%08x:decode] stall waiting for operands", csrFile.cycle_counter, programCounter);
            end else begin
                instructionMemory.deq();
                fetchInfoQueue.deq();

                // Read the source operand registers since the scoreboard indicates it's available.
                if (isValid(decodedInstruction.rs1))
                    decodedInstruction.rs1Value = registerFile.read1(fromMaybe(?, decodedInstruction.rs1));

                if (isValid(decodedInstruction.rs2))
                    decodedInstruction.rs2Value = registerFile.read2(fromMaybe(?, decodedInstruction.rs2));

                $display("[%08d:%08x:decode] decode complete", csrFile.cycle_counter, programCounter, fshow(decodedInstruction));

                // Send the decode result to the output queue.
                decodedInstructionQueue.enq(decodedInstruction);
                scoreboard.insert(decodedInstruction.rd);
            end
        end
    endrule

    //
    // Stage 3 - Instruction execution
    //
    RVExecutor instructionExecutor <- mkRVExecutor(csrFile);
    FIFO#(RVExecutedInstruction) executedInstructionQueue <- mkFIFO1();
    Reg#(PipelineEpoch) executionEpoch <- mkReg(0);

    (* fire_when_enabled *)
    rule executeInstruction;
        if (decodedInstructionQueue.first().epoch < executionEpoch) begin
            decodedInstructionQueue.deq();
        end else begin
            let decodedInstruction = decodedInstructionQueue.first();
            decodedInstructionQueue.deq();

            $display("[%08d:%08x:execute] executing instruction", csrFile.cycle_counter, decodedInstruction.programCounter);

            // Special case handling for specific SYSTEM instructions
            if (decodedInstruction.opcode == SYSTEM) begin
                case(decodedInstruction.systemOperator)
                    pack(ECALL): begin
                        $display("[%08d:%08x:execute] ECALL instruction encountered - HALTED", csrFile.cycle_counter, decodedInstruction.programCounter);
                        $finish();
                    end
                    pack(EBREAK): begin
                        $display("[%08d:%08x:execute] EBREAK instruction encountered - HALTED", csrFile.cycle_counter, decodedInstruction.programCounter);
                        $finish();
                    end
                endcase
            end

            // let executedInstruction = executeDecodedInstruction(decodedInstruction);
            let executedInstruction <- instructionExecutor.execute(decodedInstruction);

            // If writeback data exists, that needs to be written into the previous pipeline 
            // stages using operand forwarding.
            if (executedInstruction.writeBack matches tagged Valid .wb) begin
                $display("[%08d:%08x:execute] complete (WB: x%d = %08x)", csrFile.cycle_counter, decodedInstruction.programCounter, wb.rd, wb.value);
                scoreboard.remove;
            end else begin
                // Note: any exceptions are passed through until handled inside the writeback
                // stage.
                if (executedInstruction.exception matches tagged Valid .exception) begin
                    $display("[%08d:%08x:execute] EXCEPTION:", csrFile.cycle_counter, decodedInstruction.programCounter, fshow(exception.cause));
                end else begin
                    $display("[%08d:%08x:execute] complete", csrFile.cycle_counter, decodedInstruction.programCounter);
                end
            end

            executedInstructionQueue.enq(executedInstruction);
        end
    endrule

    //
    // Stage 4 - Memory access
    //
    Reg#(Bool) waitingForLoadToComplete <- mkReg(False);
    FIFO#(RVExecutedInstruction) memoryAccessCompletedQueue <- mkFIFO1();
    Reg#(PipelineEpoch) memoryAccessEpoch <- mkReg(0);

    (* fire_when_enabled *)
    rule memoryAccess;
        let memoryAccessInfo = executedInstructionQueue.first();
        if (memoryAccessInfo.epoch < memoryAccessEpoch) begin
            executedInstructionQueue.deq();
        end else begin
            let executedInstruction = executedInstructionQueue.first();
            if(executedInstruction.loadRequest matches tagged Valid .load) begin
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
                $display("[%08d:%08x:memory] not a load/store instruction", csrFile.cycle_counter, executedInstruction.programCounter);

                executedInstructionQueue.deq();
                memoryAccessCompletedQueue.enq(executedInstruction);
            end
        end
    endrule

    // Stage 5 - Register Writeback
    Reg#(PipelineEpoch) writeBackEpoch <- mkReg(0);
    (* fire_when_enabled *)
    rule writeBack;
        if (memoryAccessCompletedQueue.first().epoch < writeBackEpoch) begin
            memoryAccessCompletedQueue.deq();
        end else begin
            let memoryAccessCompleteInstruction = memoryAccessCompletedQueue.first();

            if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
                $display("[%08d:%08x:writeback] writing result ($%08x) to register x%d", csrFile.cycle_counter, memoryAccessCompleteInstruction.programCounter, wb.value, wb.rd);
                registerFile.write(wb.rd, wb.value);
            end else begin
                $display("[%08d:%08x:writeback] NO-OP", csrFile.cycle_counter, memoryAccessCompleteInstruction.programCounter);
            end

            // Handle any exceptions
            if (memoryAccessCompleteInstruction.exception matches tagged Valid .exception) begin
                let exceptionVector = csrFile.beginException(currentPrivilegeLevel, exception.cause);

                $display("[%08d:%08x:writeback] EXCEPTION: %d - Jumping to $%08x", csrFile.cycle_counter, memoryAccessCompleteInstruction.programCounter, exception.cause, exceptionVector);
                $fatal();
            end else begin
                memoryAccessCompletedQueue.deq();
            end

            csrFile.increment_instructions_retired_counter();
        end
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
