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
