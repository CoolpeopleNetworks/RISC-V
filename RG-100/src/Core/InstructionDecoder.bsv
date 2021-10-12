import ALU::*;
import Common::*;
import Instruction::*;
import RegisterFile::*;

/*  RV32IM:
        R-type:
            0110011 - ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
        I-type:
            0000011 - LB, LH, LW, LBU, LHU
            0001111 - FENCE
            0010011 - ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
            1100111 - JALR
            1110011 - ECALL, EBREAK
        S-type:
            0100011 - SB, SH, SW
        B-type:
            1100011 - BEQ, BLE, BLT, LBE, BLTU, GBEU
        U-type:
            0010111 - AUIPC
            0110111 - LUI
        J-type:
            1101111 - JAL
*/
typedef struct {
    RegisterIndex destinationRegister;
    ALUOperator operator;
    Bit#(12) immediate;
} ALUOperation deriving(Bits, Eq);

typedef struct {
    RegisterIndex destinationRegister;
    Bit#(21) offset;
} JALOperation deriving(Bits, Eq);

typedef struct {
    RegisterIndex destinationRegister;
    LoadOperator operator;
    Bit#(12) offset;
} LoadOperation deriving(Bits, Eq);

typedef struct {
} UnsupportedOperation deriving(Bits, Eq);

// typedef union tagged {
//     UnsupportedOperation UnsupportedOperation;
//     ALUOperation ALUOperation;
//     JALOperation JALOperation;
//     LoadOperation LoadOperation;
// } Operation deriving(Bits, Eq);

// typedef struct {
//     InstructionType instructionType;

//     // These two fields are always present even if not used by 
//     // the instruction.  Reading the registers (even if not used) doesn't
//     // have any performance implications.
//     RegisterIndex sourceRegister1;
//     RegisterIndex sourceRegister2;

//     Operation operation;
// } DecodedInstruction deriving(Bits, Eq);

function DecodedInstruction decode(Word rawInstruction);
    EncodedInstruction encodedInstruction = tagged RawInstruction rawInstruction;
    return case(encodedInstruction.Common.opcode)
        // RV32IM
        //7'b0000011: decode_load(pc, encodedInstruction);    // LOAD     (I-type)
        7'b0010011: decode_opimm(encodedInstruction);       // OPIMM    (I-type)
        // 7'b0010111: decode_auipc(encodedInstruction);         // AUIPC    (U-type)
        // 7'b0100011: decode_store(encodedInstruction);         // STORE    (S-type)
        7'b0110011: decode_op(encodedInstruction);          // OP       (R-type)
        // 7'b0110111: decode_lui(encodedInstruction);           // LUI      (U-type)
        // 7'b1100011: decode_branch(encodedInstruction);        // BRANCH   (B-type)
        // 7'b1100111: decode_jalr(encodedInstruction);          // JALR     (I-type)
        //7'b1101111: decode_jal(encodedInstruction);           // JAL      (J-type)
    endcase;

endfunction

// function DecodedInstruction decode_load(EncodedInstruction encodedInstruction);
//     let loadOperator = case(encodedInstruction.ItypeInstruction.func3)
//         3'b000: Lb;
//         3'b001: Lh;
//         3'b010: Lw;
//         3'b011: UnsupporttedLoadOperator;
//         3'b100: Lbu;
//         3'b101: Lhu;
//         3'b110: UnsupporttedLoadOperator;
//         3'b111: UnsupporttedLoadOperator;
//     endcase;

//     if (loadOperator == UnsupporttedLoadOperator) begin
//         return DecodedInstruction{
//             instructionType: UNSUPPORTED,
//             sourceRegister1: 0,
//             sourceRegister2: 0
//         };
//     end else begin
//         let loadInstructino = LoadInstruction {
//             loadAddress: pc + signExtend(encodedInstruction.ItypeInstruction.immediate)
//         };
//         let loadOperation = LoadOperation {
//             destinationRegister: encodedInstruction.ItypeInstruction.destination,
//             operator: loadOperator,
//             offset: encodedInstruction.ItypeInstruction.immediate
//         };

//         let specific = tagged LoadInstruction 
//         Operation operation = tagged LoadOperation loadOperation;

//         return DecodedInstruction{
//             instructionType: LOAD,
//             sourceRegister1: encodedInstruction.RtypeInstruction.source1,
//             sourceRegister2: encodedInstruction.RtypeInstruction.source2,
//             operation: operation
//         };    
//     end
// endfunction

function DecodedInstruction decode_opimm(EncodedInstruction encodedInstruction);
    let aluOperator = case(encodedInstruction.ItypeInstruction.func3)
        3'b000: AddI;
        3'b010: SltI;
        3'b011: SltIu;
        3'b100: XorI;
        3'b110: OrI;
        3'b111: AndI;
        default: UnsupportedALUOperator;
    endcase;

    if (aluOperator == UnsupportedALUOperator) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            sourceRegister1: 0,
            sourceRegister2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: OPIMM,
            sourceRegister1: encodedInstruction.RtypeInstruction.source1,
            sourceRegister2: 0, // Unused
            specific: tagged ALUInstruction ALUInstruction{
                destinationRegister: encodedInstruction.RtypeInstruction.destination,
                operator: aluOperator,
                immediate: signExtend(encodedInstruction.ItypeInstruction.immediate)
            }
        };
    end
endfunction

// function DecodedInstruction decode_auipc(Instruction instruction);
//     return DecodedInstruction{
//         iType: OP,
//         aluOperation: Add,
//         branchOperation: Eq,
//         sourceRegister1: 0,
//         sourceRegister2: 0,
//         destinationRegister: Invalid,
//         data: 0
//     };
// endfunction

// function DecodedInstruction decode_store(Instruction instruction);
//     return DecodedInstruction{
//         iType: OP,
//         aluOperation: Add,
//         branchOperation: Eq,
//         sourceRegister1: 0,
//         sourceRegister2: 0,
//         destinationRegister: Invalid,
//         data: 0
//     };
// endfunction

function DecodedInstruction decode_op(EncodedInstruction encodedInstruction);
    // Assemble the alu operation code from the func3 and func7 fields of the instruction.
    Bit#(10) aluOperationCode = 0;
    aluOperationCode[2:0] = encodedInstruction.RtypeInstruction.func3;
    aluOperationCode[9:3] = encodedInstruction.RtypeInstruction.func7;

    let aluOperator = case(aluOperationCode)
        10'b0000000000: Add;
        10'b0000000001: Sll;
        10'b0000000010: Slt;
        10'b0000000011: Sltu;
        10'b0000000100: Xor;
        10'b0000000101: Srl;
        10'b0000000110: Or;
        10'b0000000111: And;
        10'b0100000000: Sub;
        10'b0100000101: Sra;
        default: UnsupportedALUOperator;
    endcase;

    if (aluOperator == UnsupportedALUOperator) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            sourceRegister1: 0,
            sourceRegister2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: OP,
            sourceRegister1: encodedInstruction.RtypeInstruction.source1,
            sourceRegister2: encodedInstruction.RtypeInstruction.source2,
            specific: tagged ALUInstruction ALUInstruction{
                destinationRegister: encodedInstruction.RtypeInstruction.destination,
                operator: aluOperator,
                immediate: 0 //Unused
            }
        };
    end
endfunction

// function DecodedInstruction decode_lui(Instruction instruction);
//     return DecodedInstruction{
//         iType: OP,
//         aluOperation: Add,
//         branchOperation: Eq,
//         sourceRegister1: 0,
//         sourceRegister2: 0,
//         destinationRegister: Invalid,
//         data: 0
//     };
// endfunction

// function DecodedInstruction decode_branch(Instruction instruction);
//     return DecodedInstruction{
//         iType: OP,
//         aluOperation: Add,
//         branchOperation: Eq,
//         sourceRegister1: 0,
//         sourceRegister2: 0,
//         destinationRegister: Invalid,
//         data: 0
//     };
// endfunction

// function DecodedInstruction decode_jalr(Instruction instruction);
//     return DecodedInstruction{
//         iType: OP,
//         aluOperation: Add,
//         branchOperation: Eq,
//         sourceRegister1: 0,
//         sourceRegister2: 0,
//         destinationRegister: Invalid,
//         data: 0
//     };
// endfunction

// function DecodedInstruction decode_jal(EncodedInstruction encodedInstruction);
//     Bit#(21) offset;
//     offset[20] = encodedInstruction.JtypeInstruction.immediate20;
//     offset[19:12] = encodedInstruction.JtypeInstruction.immediate19_12;
//     offset[11] = encodedInstruction.JtypeInstruction.immediate11;
//     offset[10:1] = encodedInstruction.JtypeInstruction.immediate10_1;
//     offset[0] = 0;

//     let jalOperation = JALOperation {
//         destinationRegister: encodedInstruction.JtypeInstruction.returnSave,
//         offset: offset
//     };

//     Operation operation = tagged JALOperation jalOperation;

//     return DecodedInstruction{
//         instructionType: JAL,
//         sourceRegister1: 0,
//         sourceRegister2: 0,
//         operation: operation
//     };
// endfunction
