import RVTypes::*;
import EncodedInstruction::*;
import PipelineController::*;
import ExecutedInstruction::*;
import DataMemory::*;
import GetPut::*;
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
    DataMemory dataMemory
)(MemoryAccessUnit);
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO();
    Reg#(Bool) waitingForLoadToComplete <- mkReg(False);

    (* fire_when_enabled *)
    rule memoryAccess;
        let executedInstruction = inputQueue.first();
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);

        if (!pipelineController.isCurrentEpoch(stageNumber, 1, executedInstruction.epoch)) begin
            $display("%0d,%0d,%0d,%0d,memory access,stale instruction (%0d != %0d)...ignoring", cycleCounter, stageEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().epoch, stageEpoch);
            inputQueue.deq();
        end else begin
            if(executedInstruction.loadRequest matches tagged Valid .load) begin
                $display("%0d,%0d,%0d,%0d,memory access,LOAD", cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                // See if a load request has completed
                if (waitingForLoadToComplete) begin
                    // if (dataMemory.isLoadReady()) begin
                    //     waitingForLoadToComplete <= False;
                    //     $display("[%0d:%08x:memory] Load completed", cycleCounter, executedInstruction.decodedInstruction.programCounter);

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
                    //     $display("[%0d:%08x:memory] Executing LOAD", cycleCounter, executedInstruction.decodedInstruction.programCounter);
                    //     waitingForLoadToComplete <= True;
                    // end else begin
                    //     // Instruction was a store, no need to wait for a response.
                    //     $display("[%0d:%08x:memory] Executing STORE", cycleCounter, executedInstruction.decodedInstruction.programCounter);
                    //     executedInstructionQueue.deq();
                    //     memoryAccessCompletedQueue.enq(executedInstruction);
                    // end
                end
            end else begin
                // Not a LOAD/STORE
                $display("%0d,%0d,%0d,%0d,memory access,NO-OP", cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);

                inputQueue.deq();
                outputQueue.enq(executedInstruction);
            end
        end
    endrule

    interface FIFO getMemoryAccessedInstructionQueue = outputQueue;
endmodule
