import RVRegisterBypass::*;
import RVRegisterFile::*;
import RVTypes::*;

module mkBypassedRegisterFile#(
    Wire#(RVRegisterBypass) a,
    Wire#(RVRegisterBypass) b
)
(RVRegisterFile);

    RVRegisterFile registerFile <- mkRVRegisterFile();

    method Word read1(RegisterIndex index);
        // TODO: Check bypass first
        return registerFile.read1(index);
    endmethod

    method Word read2(RegisterIndex index);
        // TODO: Check bypass first
        return registerFile.read2(index);
    endmethod

    method Action write(RegisterIndex index, Word value);
        registerFile.write(index, value);
    endmethod

endmodule
