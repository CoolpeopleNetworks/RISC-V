import RVTypes::*;
import RVInstruction::*;
import RVExceptions::*;

import ExecutedInstruction::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import RVRegisterFile::*;
import RVCSRFile::*;

import GetPut::*;
import FIFO::*;
import SpecialFIFOs::*;

export WritebackUnit(..), mkWritebackUnit;

interface WritebackUnit;
    interface Put#(ExecutedInstruction) putMemoryAccessedInstruction;
endinterface

module mkWritebackUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    ProgramCounterRedirect programCounterRedirect,
    RVRegisterFile registerFile,
    RVCSRFile csrFile,
    Reg#(PrivilegeLevel) currentPrivilegeLevel,
    Reg#(Bool) instructionRetired,
    Bool pipelined
)(WritebackUnit);
    FIFO#(ExecutedInstruction) inputQueue <- mkPipelineFIFO();

    (* fire_when_enabled *)
    rule writeBack;
        let memoryAccessCompleteInstruction = inputQueue.first();
        let stageEpoch = pipelineController.stageEpoch(stageNumber);

        if (!pipelineController.isCurrentEpoch(stageNumber, memoryAccessCompleteInstruction.epoch)) begin
            $display("%0d,%0d,%0d,%0d,writeback,stale instruction (%0d != %0d)...ignoring", cycleCounter, stageEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().epoch, stageEpoch);
            inputQueue.deq();
        end else begin
            if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,%0d,writeback,writing result ($%08x) to register x%0d", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber, wb.value, wb.rd);
                registerFile.write(wb.rd, wb.value);
            end else begin
                $display("%0d,%0d,%0d,%0d,writeback,NO-OP", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber);
            end

            // Handle any exceptions
            if (memoryAccessCompleteInstruction.exception matches tagged Valid .exception) begin
                pipelineController.flush0();

                let exceptionVector <- csrFile.beginException(currentPrivilegeLevel, exception.cause);
                programCounterRedirect.exception(exceptionVector); 

                $display("%0d,%0d,%0d,%0d,writeback,EXCEPTION: %0d - Jumping to $%08x", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber, exception.cause, exceptionVector);
                $fatal();
            end
            $display("%0d,%0d,%0d,%0d,writeback,---------------------------", cycleCounter, stageEpoch, memoryAccessCompleteInstruction.programCounter, stageNumber);
            csrFile.increment_instructions_retired_counter();
        end

        instructionRetired <= True;
    endrule

    interface Put putMemoryAccessedInstruction = fifoToPut(inputQueue);
endmodule
