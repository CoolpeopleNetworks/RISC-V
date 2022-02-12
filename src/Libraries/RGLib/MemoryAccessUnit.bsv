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
                    dataMemory.request.put(DataMemoryRequest {
                        a_opcode: pack(A_GET),
                        a_param: 0,
                        a_size: 1,
                        a_source: 0,
                        a_address: loadRequest.effectiveAddress,
`ifdef RV64
                        a_mask: 8'b1111_1111,
`else // RV32
                        a_mask: 4'b1111,
`endif
                        a_data: ?,
                        a_corrupt: False
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

        if (memoryResponse.d_opcode != pack(D_ACCESS_ACK_DATA)) begin
            $display("[%0d:****:memory] FATAL - Load returned unexpected opcode: ", fshow(memoryResponse));
            $fatal();
        end

        if (memoryResponse.d_denied) begin
            $display("[%0d:****:memory] FATAL - Load returned access denied: ", fshow(memoryResponse));
            $fatal();
        end

        if (memoryResponse.d_corrupt) begin
            $display("[%0d:****:memory] FATAL - Load returned access corrupted: ", fshow(memoryResponse));
            $fatal();
        end

        // Save the data that will be written back into the register file on the
        // writeback pipeline stage.
        let loadRequest = unJust(executedInstruction.loadRequest);
        executedInstruction.writeBack = tagged Valid WriteBack {
            rd: loadRequest.rd,
            value: memoryResponse.d_data
        };

        inputQueue.deq();
        outputQueue.enq(executedInstruction);
    endrule

    interface FIFO getMemoryAccessedInstructionQueue = outputQueue;
endmodule
