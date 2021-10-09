import Common::*;
import Vector::*;

interface RegisterFile;
    method Word read1(RegisterIndex index);
    method Word read2(RegisterIndex index);
    method Action write(RegisterIndex index, Word value);
endinterface

(* synthesize *)
module mkRegisterFile(RegisterFile);
    Vector#(32, Reg#(Word)) registers <- replicateM(mkReg(0));

    method Word read1(RegisterIndex index) = registers[index];
    method Word read2(RegisterIndex index) = registers[index];

    method Action write(RegisterIndex index, Word value);
        if (index != 0) begin
            registers[index] <= value;
        end
    endmethod

endmodule
