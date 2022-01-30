import RVTypes::*;
import RVInstruction::*;

interface RVALU;
    method Maybe#(Word) execute(RVALUOperator operator, Word operand1, Word operand2);
endinterface

(* synthesize *)
module mkRVALU(RVALU);
    function Word setLessThanUnsigned(Word operand1, Word operand2);
        return (operand1 < operand2 ? 1 : 0);
    endfunction

    function Word setLessThan(Word operand1, Word operand2);
        Int#(32) signedOperand1 = unpack(pack(operand1));
        Int#(32) signedOperand2 = unpack(pack(operand2));
        return (signedOperand1 < signedOperand2 ? 1 : 0);
    endfunction

    method Maybe#(Word) execute(RVALUOperator operator, Word operand1, Word operand2);
        return case(unpack(operator))
            ADD:    tagged Valid (operand1 + operand2);
            SUB:    tagged Valid (operand1 - operand2);
            AND:    tagged Valid (operand1 & operand2);
            OR:     tagged Valid (operand1 | operand2);
            XOR:    tagged Valid (operand1 ^ operand2);
            SLTU:   tagged Valid setLessThanUnsigned(operand1, operand2);
            SLT:    tagged Valid setLessThan(operand1, operand2);
            SLL:    tagged Valid (operand1 << operand2[4:0]);
            SRA:    tagged Valid signedShiftRight(operand1, operand2[4:0]);
            SRL:    tagged Valid (operand1 >> operand2[4:0]);
            default: tagged Invalid;
        endcase;
    endmethod
endmodule
