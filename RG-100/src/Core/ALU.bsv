import Common::*;

typedef enum {
    Add,
    AddI,    
    Sub, 
    And, 
    AndI,
    Or,
    OrI,
    Xor, 
    XorI,
    Slt,
    SltI,
    Sltu,
    SltIu, 
    Sll, 
    Sra, 
    Srl,
    UnsupportedALUOperator
} ALUOperator deriving(Bits, Eq);

function Word execute(Word operand1, Word operand2, ALUOperator operator);
    return case(operator)
        Add:    (operand1 + operand2);
        Sub:    (operand1 - operand2);
        And:    (operand1 & operand2);
        Or:     (operand1 | operand2);
        Xor:    (operand1 ^ operand2);
        Sltu:   sltu(operand1, operand2);
        Slt:    slt(operand1, operand2);
        Sll:    (operand1 << operand2);
        Sra:    sra(operand1, operand2);
        Srl:    (operand1 >> operand2);
        // BUGBUG: how to handle invalid operators?
    endcase;
endfunction

function Word executeImmediate(Word operand1, Word immediate, ALUOperator operator);
    return case(operator)
        AddI:    (operand1 + immediate);
        AndI:    (operand1 & immediate);
        OrI:     (operand1 | immediate);
        XorI:    (operand1 ^ immediate);
        SltIu:   sltu(operand1, immediate);
        SltI:    slt(operand1, immediate);
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
    Eq, 
    Neq, 
    Lt, 
    Ltu, 
    Ge, 
    Geu
} BranchOperation deriving(Bits, Eq);

function Bool aluBranch(Word a, Word b, BranchOperation op);
    return case(op)
        Eq: (a == b);
        Neq: (a != b);
        Lt: signedLT(a, b);
        Ltu: (a < b);
        Ge: signedGE(a, b);
        Geu: (a >= b);
    endcase;
endfunction
