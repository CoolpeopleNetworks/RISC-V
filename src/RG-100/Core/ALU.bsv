import Common::*;

typedef enum {
    ADD,
    AND, 
    OR,
    SLT,
    SLTU,
    SLL, 
    SRA, 
    SRL,
    SUB, 
    XOR
} ALUOperator deriving(Bits, Eq);

interface ALU;
    method Word execute(Word operand1, Word operand2, ALUOperator operator);
    method Word execute_immediate(Word operand1, Bit#(12) immediate, ALUOperator operator);
endinterface

(* synthesize *)
module mkALU(ALU);
    function Word setLessThanUnsigned(Word operand1, Word operand2);
        return (operand1 < operand2 ? 1 : 0);
    endfunction

    function Word setLessThan(Word operand1, Word operand2);
        Int#(32) signedOperand1 = unpack(pack(operand1));
        Int#(32) signedOperand2 = unpack(pack(operand2));
        return (signedOperand1 < signedOperand2 ? 1 : 0);
    endfunction

    function Word execute_internal(Word operand1, Word operand2, ALUOperator operator);
        return case(operator)
            ADD:    (operand1 + operand2);
            SUB:    (operand1 - operand2);
            AND:    (operand1 & operand2);
            OR:     (operand1 | operand2);
            XOR:    (operand1 ^ operand2);
            SLTU:   setLessThanUnsigned(operand1, operand2);
            SLT:    setLessThan(operand1, operand2);
            SLL:    (operand1 << operand2[4:0]);
            SRA:    signedShiftRight(operand1, operand2[4:0]);
            SRL:    (operand1 >> operand2[4:0]);
            // BUGBUG: how to handle invalid operators?
        endcase;
    endfunction

    method Word execute(Word operand1, Word operand2, ALUOperator operator);
        return execute_internal(operand1, operand2, operator);
    endmethod

    method Word execute_immediate(Word operand1, Bit#(12) immediate, ALUOperator operator);
        return execute_internal(operand1, signExtend(immediate), operator);
    endmethod
endmodule
