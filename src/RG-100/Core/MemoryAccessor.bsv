import FIFO::*;
import Instruction::*;
import DataMemory::*;
import RVOperandForward::*;
import RVTypes::*;

// ================================================================
// Exports
export MemoryAccessor (..), mkMemoryAccessor;

interface MemoryAccessor;
endinterface

module mkMemoryAccessor#(
    Reg#(Word) cycleCounter,
    FIFO#(ExecutedInstruction) inputQueue,
    DataMemory dataMemory,
    RWire#(RVOperandForward) operandForward,
    FIFO#(ExecutedInstruction) outputQueue
)
(MemoryAccessor);

    Reg#(ExecutedInstruction) waitingForResponse <- mkRegU();

    rule sendRequest;
        let executedInstruction = inputQueue.first();
        inputQueue.deq();

        $display("%d [memory] executing instruction at $%08x", cycleCounter, executedInstruction.decodedInstruction.programCounter);

        if (executedInstruction.loadStore matches tagged Valid .loadStore) begin
            // NOTE: Alignment checks were already performed during the execution stage.
            dataMemory.request(loadStore.effectiveAddress, loadStore.storeValue, loadStore.writeEnable);

            // If this is a store operation, move to the next stage
            // (Store operations stop here...there's no writeback possible)
            if (loadStore.writeEnable == 0) begin
                waitingForResponse <= executedInstruction;
            end
        end else begin
            // Not a LOAD/STORE
            outputQueue.enq(executedInstruction);
        end

    endrule

    // This is only used for LOAD oeprations, STORE operations don't receive responses.
    rule receiveResponse;
        let memoryResponse = dataMemory.first();
        dataMemory.deq();

        let executedInstruction = waitingForResponse;
        $display("%d [memory] received LOAD data at $%08x", cycleCounter, executedInstruction.decodedInstruction.programCounter);

        // Save the data that will be written back into the register file on the
        // writeback pipeline stage.
        executedInstruction.writeBack = tagged Valid Writeback {
            rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
            value: memoryResponse
        };

        // Forward the received data
        operandForward.wset(RVOperandForward{
            rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
            value: tagged Valid memoryResponse
        });

        outputQueue.enq(executedInstruction);
    endrule
endmodule
