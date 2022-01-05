import FIFOF::*;
import Instruction::*;
import MemUtil::*;
import Port::*;
import RVOperandForward::*;
import RVTypes::*;

// ================================================================
// Exports
export MemoryAccessor (..), mkMemoryAccessor;

interface MemoryAccessor;
endinterface

module mkMemoryAccessor#(
    FIFOF#(ExecutedInstruction) executedInstructionQueue,
    AtomicMemServerPort#(32, TLog#(TDiv#(32,8))) dataMemory,
    RWire#(RVOperandForward) operandForward,
    FIFOF#(ExecutedInstruction) memoryAccessCompleteQueue
)
(MemoryAccessor);

    rule execute;
        let executedInstruction = executedInstructionQueue.first();
        executedInstructionQueue.deq();

        if (executedInstruction.loadStore matches tagged Valid .loadStore) begin
            // TODO: Check for misaligned effective address.

            dataMemory.request.enq(AtomicMemReq {
                        write_en: loadStore.writeEnable,
                        atomic_op: None,
                        addr: loadStore.effectiveAddress,
                        data: loadStore.storeValue
            });

            // If this is a load operation, wait for the load to complete.
            if (loadStore.writeEnable == 0) begin
                let memoryResponse = dataMemory.response.first();
                dataMemory.response.deq();

                // Save the data that will be written back into the register file on the
                // writeback pipeline stage.
                executedInstruction.writeBack = tagged Valid Writeback {
                    rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
                    value: memoryResponse.data
                };

                // Write the received value into the register bypass
                operandForward.wset(RVOperandForward{
                    rd: executedInstruction.decodedInstruction.specific.LoadInstruction.rd,
                    value: tagged Valid memoryResponse.data
                });
            end
        end

        memoryAccessCompleteQueue.enq(executedInstruction);
    endrule
endmodule
