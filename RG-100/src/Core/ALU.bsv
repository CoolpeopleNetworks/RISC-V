import Common::*;

typedef enum {
    ADD,
    ADDI,    
    SUB, 
    AND, 
    ANDI,
    OR,
    ORI,
    XOR, 
    XORI,
    SLT,
    SLTI,
    SLTU,
    SLTIU, 
    SLL, 
    SRA, 
    SRL,
    UNSUPPORTED_ALU_OPERATOR
} ALUOperator deriving(Bits, Eq);

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

function Word executeImmediate(Word operand1, Word immediate, ALUOperator operator);
    return case(operator)
        ADDI:    (operand1 + immediate);
        ANDI:    (operand1 & immediate);
        ORI:     (operand1 | immediate);
        XORI:    (operand1 ^ immediate);
        SLTIU:   sltu(operand1, immediate);
        SLTI:    slt(operand1, immediate);
        // BUGBUG: how to handle invalid operators?
    endcase;
endfunction
function Word slt(Word a, Word b);
    return (signedLT(a, b) ? 1 : 0);
endfunction

function Word sltu(Word a, Word b);
    return (a < b ? 1 : 0);
endfunction

function Word sra(Word a, Word b);
    return 0;
endfunction

typedef enum {
    EQ, 
    NEQ, 
    LT, 
    LTU, 
    GE, 
    GEU
} BranchOperation deriving(Bits, Eq);

function Bool aluBranch(Word a, Word b, BranchOperation op);
    return case(op)
        EQ: (a == b);
        NEQ: (a != b);
        LT: signedLT(a, b);
        LTU: (a < b);
        GE: signedGE(a, b);
        GEU: (a >= b);
    endcase;
endfunction
