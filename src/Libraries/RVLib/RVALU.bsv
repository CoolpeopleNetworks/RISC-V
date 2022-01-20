import RVTypes::*;

typedef Bit#(10) RVALUOperator;

typedef enum {  // NOTE: These are decoded as the concat of func7 and func3
    ADD    = 10'b0000000000,
    SLL    = 10'b0000000001,
    SLT    = 10'b0000000010, 
    SLTU   = 10'b0000000011, 
    XOR    = 10'b0000000100,
    SRL    = 10'b0000000101,
    OR     = 10'b0000000110,
    AND    = 10'b0000000111,
`ifdef ISA_M
    MUL    = 10'b0000001000,
    MULH   = 10'b0000001001,
    MULHSU = 10'b0000001010,
    MULHU  = 10'b0000001011,
    DIV    = 10'b0000001100,
    DIVU   = 10'b0000001101,
    REM    = 10'b0000001110,
    REMU   = 10'b0000001111,
`endif
    SUB    = 10'b0100000000,
    SRA    = 10'b0100000101,
    UNSUPPORTED_ALU_OPERATOR = 10'b1111111111
} RVALUOperators deriving(Bits, Eq, FShow);

interface RVALU;
    method Word execute(Word operand1, Word operand2, RVALUOperator operator);
    method Word execute_immediate(Word operand1, Bit#(12) immediate, RVALUOperator operator);
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

    function Word execute_internal(Word operand1, Word operand2, RVALUOperator operator);
        return case(unpack(operator))
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

    method Word execute(Word operand1, Word operand2, RVALUOperator operator);
        return execute_internal(operand1, operand2, operator);
    endmethod

    method Word execute_immediate(Word operand1, Bit#(12) immediate, RVALUOperator operator);
        return execute_internal(operand1, signExtend(immediate), operator);
    endmethod
endmodule
