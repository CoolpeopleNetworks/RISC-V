import RVTypes::*;

import CSRFile::*;
import ExecutedInstruction::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import RegisterFile::*;

import DReg::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export WritebackUnit(..), mkWritebackUnit;

interface WritebackUnit;
    method Bool wasInstructionRetired;
endinterface

module mkWritebackUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    FIFO#(ExecutedInstruction) inputQueue,
    ProgramCounterRedirect programCounterRedirect,
    RegisterFile registerFile,
    CSRFile csrFile,
    Reg#(PrivilegeLevel) currentPrivilegeLevel
)(WritebackUnit);
    Reg#(Bool) instructionRetired <- mkDReg(False);

    (* fire_when_enabled *)
    rule writeBack;
        let memoryAccessCompleteInstruction = inputQueue.first();
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 0);

        if (!pipelineController.isCurrentEpoch(stageNumber, 0, memoryAccessCompleteInstruction.epoch)) begin
            $display("%0d,%0d,%0d,%0d,writeback,stale instruction (%0d != %0d)...ignoring", cycleCounter, stageEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().epoch, stageEpoch);
            inputQueue.deq();
        end else begin
            inputQueue.deq();
            if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,%0d,writeback,writing result ($%08x) to register x%0d", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber, wb.value, wb.rd);
                registerFile.write(wb.rd, wb.value);
            end else begin
                $display("%0d,%0d,%0d,%0d,writeback,NO-OP", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber);
            end

            // Handle any exceptions
            if (memoryAccessCompleteInstruction.exception matches tagged Valid .exception) begin
                pipelineController.flush(0);

                let exceptionVector <- csrFile.beginException(currentPrivilegeLevel, exception.cause);
                programCounterRedirect.exception(exceptionVector); 

                $display("%0d,%0d,%0d,%0d,writeback,EXCEPTION: %0d - Jumping to $%08x", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber, exception.cause, exceptionVector);
                $fatal();
            end
            $display("%0d,%0d,%0d,%0d,writeback,---------------------------", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber);
            csrFile.increment_instructions_retired_counter();
            instructionRetired <= True;
        end
    endrule

    method Bool wasInstructionRetired;
        return instructionRetired;
    endmethod
endmodule
