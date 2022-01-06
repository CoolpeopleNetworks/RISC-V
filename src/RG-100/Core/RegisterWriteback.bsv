import FIFO::*;
import RVRegisterFile::*;
import RVTypes::*;
import Instruction::*;

interface RegisterWriteback;
endinterface

module mkRegisterWriteback#(
    Reg#(Word) cycleCounter,
    FIFO#(ExecutedInstruction) inputQueue,
    RVRegisterFile registerFile
)(RegisterWriteback);

    rule execute;
        let memoryAccessCompleteInstruction = inputQueue.first();
        inputQueue.deq();

        $display("%d [writeback] executing instruction at $%08x", cycleCounter, memoryAccessCompleteInstruction.decodedInstruction.programCounter);

        if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
            registerFile.write(wb.rd, wb.value);
        end
    endrule
endmodule
