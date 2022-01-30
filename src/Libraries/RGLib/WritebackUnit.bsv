import RGTypes::*;

import CSRFile::*;
import ExecutedInstruction::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import RegisterFile::*;
import Scoreboard::*;

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
    Scoreboard#(4) scoreboard, 
    RegisterFile registerFile,
    CSRFile csrFile,
    Reg#(RVPrivilegeLevel) currentPrivilegeLevel
)(WritebackUnit);
    Reg#(Bool) instructionRetired <- mkDReg(False);

    (* fire_when_enabled *)
    rule writeBack;
        let memoryAccessCompleteInstruction = inputQueue.first();
        let fetchIndex = memoryAccessCompleteInstruction.fetchIndex;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 0);

        if (!pipelineController.isCurrentEpoch(stageNumber, 0, memoryAccessCompleteInstruction.epoch)) begin
            $display("%0d,%0d,%0d,%0d,writeback,stale instruction (%0d != %0d)...ignoring", fetchIndex, cycleCounter, memoryAccessCompleteInstruction.epoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().epoch, stageEpoch);
            inputQueue.deq();
        end else begin
            inputQueue.deq();
            if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,%0d,%0d,writeback,writing result ($%08x) to register x%0d", fetchIndex, cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber, wb.value, wb.rd);
                registerFile.write(wb.rd, wb.value);
            end else begin
                $display("%0d,%0d,%0d,%0d,%0d,writeback,NO-OP", fetchIndex, cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber);
            end

            scoreboard.remove;

            //
            // Handle any exceptions
            //
            if (memoryAccessCompleteInstruction.exception matches tagged Valid .exception) begin
                pipelineController.flush(0);

                Word exceptionCause = ?;
                exceptionCause[valueOf(XLEN)-1] = (exception.isInterrupt ? 1 : 0);
                if (exception.isInterrupt) begin
                    exceptionCause[valueOf(XLEN)-2:0] = pack(exception.cause.Interrupt);
                end else begin
                    exceptionCause[valueOf(XLEN)-2:0] = pack(exception.cause.Exception);
                end

                let exceptionVector <- csrFile.beginException(currentPrivilegeLevel, exception);
                programCounterRedirect.exception(exceptionVector); 

                $display("%0d,%0d,%0d,%0d,%0d,writeback,EXCEPTION: %0d - Jumping to $%08x", fetchIndex, cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber, exception.cause, exceptionVector);
                $fatal();
            end
            $display("%0d,%0d,%0d,%0d,%0d,writeback,---------------------------", fetchIndex, cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber);
            csrFile.increment_instructions_retired_counter();
            instructionRetired <= True;
        end
    endrule

    method Bool wasInstructionRetired;
        return instructionRetired;
    endmethod
endmodule
