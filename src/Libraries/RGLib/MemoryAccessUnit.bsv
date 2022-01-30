import RGTypes::*;

import DataMemory::*;
import EncodedInstruction::*;
import ExecutedInstruction::*;
import PipelineController::*;

import Assert::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export MemoryAccessUnit(..), mkMemoryAccessUnit;

interface MemoryAccessUnit;
    interface FIFO#(ExecutedInstruction) getMemoryAccessedInstructionQueue;
endinterface

module mkMemoryAccessUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    FIFO#(ExecutedInstruction) inputQueue,
    DataMemory dataMemory
)(MemoryAccessUnit);
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO();
    Reg#(Bool) waitingForLoadToComplete <- mkReg(False);
    Reg#(ExecutedInstruction) instructionWaitingForLoad <- mkRegU();

    (* fire_when_enabled *)
    rule memoryAccess(waitingForLoadToComplete == False);
        let executedInstruction = inputQueue.first();
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);

        if (!pipelineController.isCurrentEpoch(stageNumber, 1, executedInstruction.epoch)) begin
            $display("%0d,%0d,%0d,%0d,memory access,stale instruction (%0d != %0d)...ignoring", cycleCounter, executedInstruction.epoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().epoch, stageEpoch);
            inputQueue.deq();
        end else begin
            if(executedInstruction.loadRequest matches tagged Valid .loadRequest) begin
                $display("%0d,%0d,%0d,%0d,memory access,LOAD", cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                begin
                    // NOTE: Alignment checks were already performed during the execution stage.
                    dataMemory.request(loadRequest.effectiveAddress, ?, 0);

                    $display("%0d,%0d,%0d,%0d,memory access, Loading from $%08x", cycleCounter, executedInstruction.programCounter, loadRequest.effectiveAddress);
                    instructionWaitingForLoad <= executedInstruction;
                    waitingForLoadToComplete <= True;
                end
            end else begin
                // Not a LOAD/STORE
                $display("%0d,%0d,%0d,%0d,memory access,NO-OP", cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);

                inputQueue.deq();
                outputQueue.enq(executedInstruction);
            end
        end
    endrule

    rule handleLoadResponse(waitingForLoadToComplete == True);
        let memoryResponse = dataMemory.first();
        dataMemory.deq();

        let executedInstruction = instructionWaitingForLoad;

        $display("[%0d:****:memory] Load completed", cycleCounter, executedInstruction.programCounter);

        waitingForLoadToComplete <= False;

        // Save the data that will be written back into the register file on the
        // writeback pipeline stage.
        let loadRequest = unJust(executedInstruction.loadRequest);
        executedInstruction.writeBack = tagged Valid WriteBack {
            rd: loadRequest.rd,
            value: memoryResponse
        };

        inputQueue.deq();
        outputQueue.enq(executedInstruction);
    endrule

    interface FIFO getMemoryAccessedInstructionQueue = outputQueue;
endmodule
