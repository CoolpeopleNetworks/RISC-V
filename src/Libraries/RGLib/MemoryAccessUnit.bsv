//
// MemoryAccessUnit
//
// This module is responsible for handling RISC-V LOAD and STORE instructions.  It 
// accepts a 'ExecutedInstruction' structure and if the values contained therein have
// valid LoadRequest or StoreRequest structures, the requisite load and store operations
// are executed.
//
import RGTypes::*;

import EncodedInstruction::*;
import ExecutedInstruction::*;
import MemoryInterfaces::*;
import PipelineController::*;

import Assert::*;
import FIFO::*;
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
    DataMemoryServer dataMemory
)(MemoryAccessUnit);
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO();
    Reg#(Bool) waitingForLoadToComplete <- mkReg(False);
    Reg#(ExecutedInstruction) instructionWaitingForLoad <- mkRegU();

    (* fire_when_enabled *)
    rule memoryAccess(waitingForLoadToComplete == False);
        let executedInstruction = inputQueue.first();
        let fetchIndex = executedInstruction.fetchIndex;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);

        if (!pipelineController.isCurrentEpoch(stageNumber, 1, executedInstruction.pipelineEpoch)) begin
            $display("%0d,%0d,%0d,%0d,memory access,stale instruction (%0d != %0d)...ignoring", fetchIndex, cycleCounter, executedInstruction.pipelineEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().pipelineEpoch, stageEpoch);
            inputQueue.deq();
        end else begin
            if(executedInstruction.loadRequest matches tagged Valid .loadRequest) begin
                $display("%0d,%0d,%0d,%0d,%0d,memory access,LOAD", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                begin
                    // NOTE: Alignment checks were already performed during the execution stage.
                    dataMemory.request.put(MemoryRequest {
                        write: False,
                        byteen: ?,
                        address: loadRequest.effectiveAddress,
                        data: ?
                    });

                    $display("%0d,%0d,%0d,%0d,%0d,memory access, Loading from $%08x", fetchIndex, cycleCounter, executedInstruction.programCounter, loadRequest.effectiveAddress);
                    instructionWaitingForLoad <= executedInstruction;
                    waitingForLoadToComplete <= True;
                end
            end else begin
                // Not a LOAD/STORE
                $display("%0d,%0d,%0d,%0d,%0d,memory access,NO-OP", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);

                inputQueue.deq();
                outputQueue.enq(executedInstruction);
            end
        end
    endrule

    rule handleLoadResponse(waitingForLoadToComplete == True);
        let memoryResponse <- dataMemory.response.get;
        let executedInstruction = instructionWaitingForLoad;

        $display("[%0d:****:memory] Load completed", cycleCounter, executedInstruction.programCounter);

        waitingForLoadToComplete <= False;

        // Save the data that will be written back into the register file on the
        // writeback pipeline stage.
        let loadRequest = unJust(executedInstruction.loadRequest);
        executedInstruction.writeBack = tagged Valid WriteBack {
            rd: loadRequest.rd,
            value: memoryResponse.data
        };

        inputQueue.deq();
        outputQueue.enq(executedInstruction);
    endrule

    interface FIFO getMemoryAccessedInstructionQueue = outputQueue;
endmodule
