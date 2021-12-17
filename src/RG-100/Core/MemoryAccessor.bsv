import FIFOF::*;
import Instruction::*;
import MemUtil::*;
import Port::*;
import RVRegisterBypass::*;
import RVTypes::*;

interface MemoryAccessor;
endinterface

module mkMemoryAccessor#(
    FIFOF#(ExecutedInstruction) executedInstructionQueue,
    AtomicMemServerPort#(32, TLog#(TDiv#(32,8))) dataMemory,
    Reg#(ProgramCounter) programCounter,
    Wire#(RVRegisterBypass) registerBypass,
    FIFOF#(ExecutedInstruction) memoryAccessCompleteQueue
)
(MemoryAccessor);

    rule accessMemory;
        let executedInstruction = executedInstructionQueue.first();
        executedInstructionQueue.deq();

        if ((executedInstruction.decodedInstruction.instructionType == LOAD) ||
            (executedInstruction.decodedInstruction.instructionType == STORE)) begin
            if (executedInstruction.misaligned) begin
                $display("[stage3] ERROR - Misaligned LOAD/STORE at PC: %h", programCounter);
                $fatal();
            end

            let addr = executedInstruction.effectiveAddress;
            Bit#(4) writeEnable = (executedInstruction.decodedInstruction.instructionType == LOAD ? 0 : 
                case(executedInstruction.decodedInstruction.specific.StoreInstruction.operator)
                    SB: ('b0001 << addr[1:0]);
                    SH: ('b0011 << addr[1:0]);
                    SW: ('b1111);
                endcase);

            dataMemory.request.enq(AtomicMemReq {
                        write_en: writeEnable,
                        atomic_op: None,
                        addr: executedInstruction.effectiveAddress,
                        data: executedInstruction.alignedData 
            });

            if (executedInstruction.decodedInstruction.instructionType == LOAD) begin
                registerBypass.state <= BYPASS_STATE_REGISTER_KNOWN;
                registerBypass.rd <= executedInstruction.decodedInstruction.specific.LoadInstruction.rd;
            end
        end

        if (executedInstruction.decodedInstruction.instructionType == LOAD) begin
            let memoryResponse = dataMemory.response.first();
            dataMemory.response.deq();

            executedInstruction.writeBack = executedInstruction.decodedInstruction.specific.LoadInstruction.rd;
            executedInstruction.writeBackData = memoryResponse.data;

            registerBypass.state <= BYPASS_STATE_VALUE_AVAILABLE;
            registerBypass.value <= memoryResponse.data;
        end

        memoryAccessCompleteQueue.enq(executedInstruction);
    endrule
endmodule
