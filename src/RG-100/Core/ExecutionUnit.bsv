import RVTypes::*;
import RVALU::*;
import RVInstruction::*;
import RVCSRFile::*;
import RVExceptions::*;

import DecodedInstruction::*;
import ExecutedInstruction::*;
import InstructionExecutor::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import Scoreboard::*;

import GetPut::*;
import FIFO::*;
import SpecialFIFOs::*;

export ExecutionUnit(..), mkExecutionUnit;

interface ExecutionUnit;
    interface Put#(DecodedInstruction) putDecodedInstruction;
    interface Get#(ExecutedInstruction) getExecutedInstruction;
endinterface

module mkExecutionUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    ProgramCounterRedirect programCounterRedirect,
    Scoreboard#(4) scoreboard,
    RVCSRFile csrFile,
    Reg#(Bool) halt
)(ExecutionUnit);
    FIFO#(DecodedInstruction) inputQueue <- mkPipelineFIFO();
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO();

    InstructionExecutor instructionExecutor <- mkInstructionExecutor(csrFile);

    (* fire_when_enabled *)
    rule execute;
        let decodedInstruction = inputQueue.first();
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);

        if (!pipelineController.isCurrentEpoch(stageNumber, 1, decodedInstruction.epoch)) begin
            $display("%0d,%0d,%0d,%0d,execute,stale instruction (%0d != %0d)...ignoring", csrFile.cycle_counter, stageEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().epoch, stageEpoch[1]);
            inputQueue.deq();
        end else begin
            let currentEpoch = stageEpoch;
            inputQueue.deq();

            $display("%0d,%0d,%0d,%0d,execute,executing instruction: ", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(decodedInstruction.opcode));

            // Special case handling for specific SYSTEM instructions
            if (decodedInstruction.opcode == SYSTEM) begin
                case(decodedInstruction.systemOperator)
                    pack(ECALL): begin
                        $display("%0d,%0d,%0d,%0d,execute,ECALL instruction encountered - HALTED", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                        halt <= True;
                    end
                    pack(EBREAK): begin
                        $display("%0d,%0d,%0d,%0d,execute,EBREAK instruction encountered - HALTED", csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                        halt <= True;
                    end
                endcase
            end

            let executedInstruction <- instructionExecutor.executeInstruction(decodedInstruction);

            // If the program counter was changed.
            if (isValid(executedInstruction.changedProgramCounter)) begin
                pipelineController.flush(1);

                // Bump the current instruction epoch
                executedInstruction.epoch = executedInstruction.epoch + 1;

                let targetAddress = fromMaybe(?, executedInstruction.changedProgramCounter);
                $display("%0d,%0d,%0d,%0d,execute,branch/jump to: $%08x", cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, targetAddress);
                programCounterRedirect.branch(targetAddress);
            end

            // If writeback data exists, that needs to be written into the previous pipeline 
            // stages using operand forwarding.
            if (executedInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,%0d,execute,complete (WB: x%0d = %08x)", cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, wb.rd, wb.value);
            end else begin
                // Note: any exceptions are passed through until handled inside the writeback
                // stage.
                if (executedInstruction.exception matches tagged Valid .exception) begin
                    $display("%0d,%0d,%0d,%0d,execute,EXCEPTION:", cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(exception.cause));
                end else begin
                    $display("%0d,%0d,%0d,%0d,execute,complete", cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                end
            end

            scoreboard.remove;
            outputQueue.enq(executedInstruction);
        end
    endrule

    interface Put putDecodedInstruction = fifoToPut(inputQueue);
    interface Get getExecutedInstruction = fifoToGet(outputQueue);
endmodule
