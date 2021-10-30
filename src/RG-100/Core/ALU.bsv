import Common::*;

typedef enum {
    ADD,
    SUB, 
    AND, 
    OR,
    XOR, 
    SLT,
    SLTU,
    SLL, 
    SRA, 
    SRL,
    UNSUPPORTED_ALU_OPERATOR
} ALUOperator deriving(Bits, Eq);

function Word slt(Word a, Word b);
    return (signedLT(a, b) ? 1 : 0);
endfunction

function Word sltu(Word a, Word b);
    return (a < b ? 1 : 0);
endfunction

function Word sra(Word a, Word b);
    return 0;
endfunction

function Word execute(Word operand1, Word operand2, ALUOperator operator);
    return case(operator)
        ADD:    (operand1 + operand2);
        SUB:    (operand1 - operand2);
        AND:    (operand1 & operand2);
        OR:     (operand1 | operand2);
        XOR:    (operand1 ^ operand2);
        SLTU:   sltu(operand1, operand2);
        SLT:    slt(operand1, operand2);
        SLL:    (operand1 << operand2);
        SRA:    sra(operand1, operand2);
        SRL:    (operand1 >> operand2);
        // BUGBUG: how to handle invalid operators?
    endcase;
endfunction
