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
        DataMemory dataMemory,
        Word64 cLimit,
        Bool pipelined
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
    // Pipeline stage epochs
    //
    Reg#(PipelineEpoch) fetchEpoch <- mkReg(0);
    Reg#(PipelineEpoch) decoderEpoch[3] <- mkCReg(3, 0);
    Reg#(PipelineEpoch) executionEpoch[2] <- mkCReg(2, 0);
    Reg#(PipelineEpoch) memoryAccessEpoch[2] <- mkCReg(2, 0);
    Reg#(PipelineEpoch) writeBackEpoch[2] <- mkCReg(2, 0);

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
    Reg#(ProgramCounter) fetchProgramCounter <- mkReg(initialProgramCounter);
    Reg#(Maybe#(ProgramCounter)) programCounterRedirect[3] <- mkCReg(3, tagged Invalid);
    // RWire#(ProgramCounter) programCounterRedirectExecution <- mkRWire();
    // RWire#(ProgramCounter) programCounterRedirectException <- mkRWire();

    // This FIFO holds the program counter value for the instruction that's being
    // fetched.
    FIFO#(FetchInfo) fetchInfoQueue <- mkPipelineFIFO();

    Reg#(Bool) fetchEnabled <- mkReg(True);

//    (* fire_when_enabled *)
    rule fetchInstruction(fetchEnabled == True);
        // Get the current program counter from the 'fetchProgramCounter' register, if the 
        // program counter redirect has a value, move that into the program counter and
        // increment the epoch.
        let currentEpoch = fetchEpoch;
        let programCounter = fetchProgramCounter;
        // if (programCounterRedirectException.wget() matches tagged Valid .programCounterRedirect) begin
        //     programCounter = programCounterRedirect;

        //     $display("[%0d:%08x:fetch] redirected PC (Exception) = $%08x", csrFile.cycle_counter, programCounter, programCounter);
        //     currentEpoch = fetchEpoch + 1;
        //     fetchEpoch <= currentEpoch;
        // end

        // if (programCounterRedirectExecution.wget() matches tagged Valid .programCounterRedirect) begin
        //     programCounter = programCounterRedirect;

        //     $display("[%0d:%08x:fetch] redirected PC (Branch/Jump) = $%08x", csrFile.cycle_counter, programCounter, programCounter);
        //     currentEpoch = fetchEpoch + 1;
        //     fetchEpoch <= currentEpoch;
        // end

        if (isValid(programCounterRedirect[2])) begin
            programCounter = fromMaybe(?, programCounterRedirect[2]);
            programCounterRedirect[2] <= tagged Invalid;

            currentEpoch = fetchEpoch + 1;
            fetchEpoch <= currentEpoch;

            $display("%0d,%0d,%0d,1,fetch,redirected PC: $%08x", csrFile.cycle_counter, currentEpoch, programCounter, programCounter);
        end


        $display("%0d,%0d,%0d,1,fetch,fetching instruction", csrFile.cycle_counter, currentEpoch, programCounter);

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

        if (!pipelined)
            fetchEnabled <= False;
    endrule

    //
    // Stage 2 - Instruction Decode
    //
    RVDecoder decoder <- mkRVDecoder;
    FIFO#(RVDecodedInstruction) decodedInstructionQueue <- mkFIFO1();

    (* fire_when_enabled *)
    rule decodeInstruction;
        let encodedInstruction = instructionMemory.first;
        if (fetchInfoQueue.first().epoch < decoderEpoch[2]) begin
            $display("%0d,%0d,%0d,2,decode,stale instruction (%0d != %0d)...ignoring", csrFile.cycle_counter, decoderEpoch[2], fetchInfoQueue.first.programCounter, fetchInfoQueue.first().epoch, decoderEpoch[2]);
            instructionMemory.deq();
            fetchInfoQueue.deq();
        end else begin
            let programCounter = fetchInfoQueue.first.programCounter;
            let currentEpoch = decoderEpoch[2];
            let decodedInstruction = decoder.decode(programCounter, encodedInstruction);
            decodedInstruction.epoch = decoderEpoch[2];

            let stallWaitingForOperands = scoreboard.search(decodedInstruction.rs1, decodedInstruction.rs2);
            if (stallWaitingForOperands) begin
                $display("%0d,%0d,%0d,2,decode,stall waiting for operands", csrFile.cycle_counter, currentEpoch, programCounter);
            end else begin
                instructionMemory.deq();
                fetchInfoQueue.deq();

                // Read the source operand registers since the scoreboard indicates it's available.
                if (isValid(decodedInstruction.rs1))
                    decodedInstruction.rs1Value = registerFile.read1(fromMaybe(?, decodedInstruction.rs1));

                if (isValid(decodedInstruction.rs2))
                    decodedInstruction.rs2Value = registerFile.read2(fromMaybe(?, decodedInstruction.rs2));

                $display("%0d,%0d,%0d,2,decode,decode complete", csrFile.cycle_counter, currentEpoch, programCounter);
//                $display("%0d,%0d,%0d,2,decode,", csrFile.cycle_counter, currentEpoch, programCounter, fshow(decodedInstruction));

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

    (* fire_when_enabled *)
    rule executeInstruction;
        if (decodedInstructionQueue.first().epoch < executionEpoch[1]) begin
            $display("%0d,%0d,%0d,3,execute,stale instruction (%0d != %0d)...ignoring", csrFile.cycle_counter, executionEpoch[1], decodedInstructionQueue.first().programCounter, decodedInstructionQueue.first().epoch, executionEpoch[1]);
            decodedInstructionQueue.deq();
        end else begin
            let decodedInstruction = decodedInstructionQueue.first();
            let currentEpoch = executionEpoch[1];
            decodedInstructionQueue.deq();

            $display("%0d,%0d,%0d,3,execute,executing instruction: ", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, fshow(decodedInstruction.opcode));

            // Special case handling for specific SYSTEM instructions
            if (decodedInstruction.opcode == SYSTEM) begin
                case(decodedInstruction.systemOperator)
                    pack(ECALL): begin
                        $display("%0d,%0d,%0d,3,execute,ECALL instruction encountered - HALTED", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter);
                        $finish();
                    end
                    pack(EBREAK): begin
                        $display("%0d,%0d,%0d,3,execute,EBREAK instruction encountered - HALTED", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter);
                        $finish();
                    end
                endcase
            end

            let executedInstruction <- instructionExecutor.execute(decodedInstruction);

            // If the program counter was changed.
            if (isValid(executedInstruction.changedProgramCounter)) begin
                decoderEpoch[1] <= decoderEpoch[1] + 1;
                executionEpoch[1] <= executionEpoch[1] + 1;
                memoryAccessEpoch[1] <= memoryAccessEpoch[1] + 1;
                writeBackEpoch[1] <= writeBackEpoch[1] + 1;

                // Bump the current instruction epoch
                executedInstruction.epoch = executedInstruction.epoch + 1;

                let targetAddress = fromMaybe(?, executedInstruction.changedProgramCounter);
                $display("%0d,%0d,%0d,3,execute,branch/jump to: $%08x", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, targetAddress);
                programCounterRedirect[1] <= tagged Valid targetAddress;
            end

            // If writeback data exists, that needs to be written into the previous pipeline 
            // stages using operand forwarding.
            if (executedInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,3,execute,complete (WB: x%0d = %08x)", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, wb.rd, wb.value);
                scoreboard.remove;
            end else begin
                // Note: any exceptions are passed through until handled inside the writeback
                // stage.
                if (executedInstruction.exception matches tagged Valid .exception) begin
                    $display("%0d,%0d,%0d,3,execute,EXCEPTION:", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, fshow(exception.cause));
                end else begin
                    $display("%0d,%0d,%0d,3,execute,complete", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter);
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

    (* fire_when_enabled *)
    rule memoryAccess;
        if (executedInstructionQueue.first().epoch < memoryAccessEpoch[1]) begin
            $display("%0d,%0d,%0d,4,memory access,stale instruction (%0d != %0d)...ignoring", csrFile.cycle_counter, memoryAccessEpoch[1], executedInstructionQueue.first().programCounter, executedInstructionQueue.first().epoch, memoryAccessEpoch[1]);
            executedInstructionQueue.deq();
        end else begin
            let executedInstruction = executedInstructionQueue.first();
            let currentEpoch = memoryAccessEpoch[1];
            if(executedInstruction.loadRequest matches tagged Valid .load) begin
                $display("%0d,%0d,%0d,4,memory access,LOAD", csrFile.cycle_counter, currentEpoch, executedInstruction.programCounter);
                // See if a load request has completed
                if (waitingForLoadToComplete) begin
                    // if (dataMemory.isLoadReady()) begin
                    //     waitingForLoadToComplete <= False;
                    //     $display("[%0d:%08x:memory] Load completed", csrFile.cycle_counter, executedInstruction.decodedInstruction.programCounter);

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
                    //     $display("[%0d:%08x:memory] Executing LOAD", csrFile.cycle_counter, executedInstruction.decodedInstruction.programCounter);
                    //     waitingForLoadToComplete <= True;
                    // end else begin
                    //     // Instruction was a store, no need to wait for a response.
                    //     $display("[%0d:%08x:memory] Executing STORE", csrFile.cycle_counter, executedInstruction.decodedInstruction.programCounter);
                    //     executedInstructionQueue.deq();
                    //     memoryAccessCompletedQueue.enq(executedInstruction);
                    // end
                end
            end else begin
                // Not a LOAD/STORE
                $display("%0d,%0d,%0d,4,memory access,NO-OP", csrFile.cycle_counter, currentEpoch, executedInstruction.programCounter);

                executedInstructionQueue.deq();
                memoryAccessCompletedQueue.enq(executedInstruction);
            end
        end
    endrule

    // Stage 5 - Register Writeback
    (* fire_when_enabled *)
    rule writeBack;
        let memoryAccessCompleteInstruction = memoryAccessCompletedQueue.first();
        memoryAccessCompletedQueue.deq();

        let stageEpoch = writeBackEpoch[0];
        let instructionEpoch = memoryAccessCompleteInstruction.epoch;

        if (instructionEpoch < stageEpoch) begin
            $display("%0d,%0d,%0d,5,write back,stale instruction (%0d != %0d)...ignoring", csrFile.cycle_counter, stageEpoch, memoryAccessCompleteInstruction.programCounter, memoryAccessCompleteInstruction.epoch, stageEpoch);
        end else begin
            if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,5,write back,writing result ($%08x) to register x%0d", csrFile.cycle_counter, stageEpoch, memoryAccessCompleteInstruction.programCounter, wb.value, wb.rd);
                registerFile.write(wb.rd, wb.value);
            end else begin
                $display("%0d,%0d,%0d,5,write back,NO-OP", csrFile.cycle_counter, stageEpoch, memoryAccessCompleteInstruction.programCounter);
            end

            // Handle any exceptions
            if (memoryAccessCompleteInstruction.exception matches tagged Valid .exception) begin
                let exceptionVector <- csrFile.beginException(currentPrivilegeLevel, exception.cause);

                decoderEpoch[0] <= decoderEpoch[0] + 1;
                executionEpoch[0] <= executionEpoch[0] + 1;
                memoryAccessEpoch[0] <= memoryAccessEpoch[0] + 1;
                writeBackEpoch[0] <= writeBackEpoch[0] + 1;

                programCounterRedirect[0] <= tagged Valid exceptionVector; 

                $display("%0d,%0d,%0d,5,writeback,EXCEPTION: %0d - Jumping to $%08x", csrFile.cycle_counter, stageEpoch, memoryAccessCompleteInstruction.programCounter, exception.cause, exceptionVector);
                $fatal();
            end
            $display("%0d,%0d,%0d,6,writeback,---------------------------", csrFile.cycle_counter, stageEpoch, memoryAccessCompleteInstruction.programCounter);
            csrFile.increment_instructions_retired_counter();
        end

        if (!pipelined)
            fetchEnabled <= True;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        if (cycleLimit > 0 && csrFile.cycle_counter > cycleLimit) begin
            $display("%0d,%0d,%0d,cycleCounter,Cycle limit reached...exitting.", csrFile.cycle_counter, 1000000000, 1000000000);
            $finish();
        end

        csrFile.increment_cycle_counter();
    endrule
endmodule
