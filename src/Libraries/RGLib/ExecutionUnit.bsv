import RGTypes::*;

import ALU::*;
import CSRFile::*;
import DecodedInstruction::*;
import ExecutedInstruction::*;
import InstructionExecutor::*;
import PipelineController::*;
import ProgramCounterRedirect::*;

import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export ExecutionUnit(..), mkExecutionUnit;

interface ExecutionUnit;
    interface FIFO#(ExecutedInstruction) getExecutedInstructionQueue;
endinterface

module mkExecutionUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    FIFO#(DecodedInstruction) inputQueue,
    ProgramCounterRedirect programCounterRedirect,
    CSRFile csrFile,
    Reg#(Bool) halt
)(ExecutionUnit);
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO();

    InstructionExecutor instructionExecutor <- mkInstructionExecutor(csrFile);

    (* fire_when_enabled *)
    rule execute;
        let decodedInstruction = inputQueue.first();
        let fetchIndex = decodedInstruction.fetchIndex;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);

        if (!pipelineController.isCurrentEpoch(stageNumber, 1, decodedInstruction.epoch)) begin
            $display("%0d,%0d,%0d,%0d,%0d,execute,stale instruction (%0d != %0d)...ignoring", fetchIndex, csrFile.cycle_counter, decodedInstruction.epoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().epoch, stageEpoch[1]);
            inputQueue.deq();
        end else begin
            let currentEpoch = stageEpoch;
            inputQueue.deq();

            $display("%0d,%0d,%0d,%0d,%0d,execute,executing instruction: ", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(decodedInstruction.opcode));
            $display("%0d,%0d,%0d,%0d,%0d,execute,RS1: ", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs1) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs1), decodedInstruction.rs1Value, decodedInstruction.rs1Value) : $format("INVALID")));
            $display("%0d,%0d,%0d,%0d,%0d,execute,RS2: ", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs2) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs2), decodedInstruction.rs2Value, decodedInstruction.rs2Value) : $format("INVALID")));
            
            // Special case handling for specific SYSTEM instructions
            if (decodedInstruction.opcode == SYSTEM) begin
                case(decodedInstruction.systemOperator)
                    pack(ECALL): begin
                        $display("%0d,%0d,%0d,%0d,%0d,execute,ECALL instruction encountered - HALTED", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                        halt <= True;
                    end
                    pack(EBREAK): begin
                        $display("%0d,%0d,%0d,%0d,%0d,execute,EBREAK instruction encountered - HALTED", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                        halt <= True;
                    end
                endcase
            end

            let executedInstruction <- instructionExecutor.executeInstruction(decodedInstruction);

            // If the program counter was changed, see if it matches a predicted branch/jump.
            // If not, redirect the program counter to the mispredicted target address.
            if (isValid(executedInstruction.changedProgramCounter)) begin
                let targetAddress = unJust(executedInstruction.changedProgramCounter);
                if (decodedInstruction.predictedNextProgramCounter != targetAddress) begin
                    pipelineController.flush(1);

                    // Bump the current instruction epoch
                    executedInstruction.epoch = executedInstruction.epoch + 1;

                    $display("%0d,%0d,%0d,%0d,%0d,execute,branch/jump to: $%08x", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, targetAddress);
                    programCounterRedirect.branch(targetAddress);
                end
            end

            // If writeback data exists, that needs to be written into the previous pipeline 
            // stages using operand forwarding.
            if (executedInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,%0d,%0d,execute,complete (WB: x%0d = %08x)", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, wb.rd, wb.value);
            end else begin
                // Note: any exceptions are passed through until handled inside the writeback
                // stage.
                if (executedInstruction.exception matches tagged Valid .exception) begin
                    $display("%0d,%0d,%0d,%0d,%0d,execute,EXCEPTION:", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(exception.cause));
                end else begin
                    $display("%0d,%0d,%0d,%0d,%0d,execute,complete", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                end
            end

            outputQueue.enq(executedInstruction);
        end
    endrule

    interface FIFO getExecutedInstructionQueue = outputQueue;
endmodule
