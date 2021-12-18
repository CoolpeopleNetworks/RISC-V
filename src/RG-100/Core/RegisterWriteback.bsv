import FIFOF::*;
import RVRegisterFile::*;
import Instruction::*;

interface RegisterWriteback;
endinterface

module mkRegisterWriteback#(
    FIFOF#(ExecutedInstruction) inputQueue,
    RVRegisterFile registerFile
)(RegisterWriteback);

    rule execute;
        let memoryAccessCompleteInstruction = inputQueue.first();
        inputQueue.deq();

        if (memoryAccessCompleteInstruction.writeBack matches tagged Valid .wb) begin
            registerFile.write(wb.rd, wb.value);
        end
    endrule
endmodule
