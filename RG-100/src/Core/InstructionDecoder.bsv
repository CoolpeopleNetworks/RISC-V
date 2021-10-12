import ALU::*;
import Common::*;
import Instruction::*;

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

function DecodedInstruction decode(Word rawInstruction);
    EncodedInstruction encodedInstruction = tagged RawInstruction rawInstruction;
    return case(encodedInstruction.Common.opcode)
        // RV32I
        7'b0000011: decode_load(encodedInstruction);        // LOAD     (I-type)
        7'b0010011: decode_opimm(encodedInstruction);       // OPIMM    (I-type)
        7'b0010111: decode_auipc(encodedInstruction);       // AUIPC    (U-type)
        7'b0100011: decode_store(encodedInstruction);       // STORE    (S-type)
        7'b0110011: decode_op(encodedInstruction);          // OP       (R-type)
        7'b0110111: decode_lui(encodedInstruction);         // LUI      (U-type)
        7'b1100011: decode_branch(encodedInstruction);      // BRANCH   (B-type)
        7'b1100111: decode_jalr(encodedInstruction);        // JALR     (I-type)
        7'b1101111: decode_jal(encodedInstruction);         // JAL      (J-type)
        default: DecodedInstruction{
            instructionType: UNSUPPORTED,
            source1: 0,
            source2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    endcase;
endfunction

//
// decode_auipc
//
function DecodedInstruction decode_auipc(EncodedInstruction encodedInstruction);
    Word effectiveAddress = 0;
    effectiveAddress[31:12] = encodedInstruction.UtypeInstruction.immediate31_12;

    return DecodedInstruction{
        instructionType: AUIPC,
        source1: 0, // Unused
        source2: 0, // Unused
        specific: tagged AUIPCInstruction AUIPCInstruction{
            destination: encodedInstruction.UtypeInstruction.destination,
            effectiveAddress: effectiveAddress
        }
    };
endfunction

//
// decode_branch
//
function DecodedInstruction decode_branch(EncodedInstruction encodedInstruction);
    Bit#(13) offset = 0;
    offset[12] = encodedInstruction.BtypeInstruction.immediate12;
    offset[11] = encodedInstruction.BtypeInstruction.immediate11;
    offset[10:5] = encodedInstruction.BtypeInstruction.immediate10_5;
    offset[4:1] = encodedInstruction.BtypeInstruction.immediate4_1;

    let branchOperator = case(encodedInstruction.BtypeInstruction.func3)
        3'b000: BEQ;
        3'b001: BNE;
        3'b100: BLT;
        3'b101: BGE;
        3'b110: BLTU;
        3'b111: BGEU;
        default: UNSUPPORTED_BRANCH_OPERATOR;
    endcase;

    if (branchOperator == UNSUPPORTED_BRANCH_OPERATOR) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            source1: 0,
            source2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: BRANCH,
            source1: encodedInstruction.BtypeInstruction.source1,
            source2: encodedInstruction.BtypeInstruction.source2,
            specific: tagged BranchInstruction BranchInstruction{
                offset: offset,
                operator: branchOperator
            }
        };
    end
endfunction

//
// decode_jal
//
function DecodedInstruction decode_jal(EncodedInstruction encodedInstruction);
    Bit#(21) offset;
    offset[20] = encodedInstruction.JtypeInstruction.immediate20;
    offset[19:12] = encodedInstruction.JtypeInstruction.immediate19_12;
    offset[11] = encodedInstruction.JtypeInstruction.immediate11;
    offset[10:1] = encodedInstruction.JtypeInstruction.immediate10_1;
    offset[0] = 0;

    return DecodedInstruction{
        instructionType: JAL,
        source1: 0, // Unused
        source2: 0, // Unused
        specific: tagged JALInstruction JALInstruction{
            destination: encodedInstruction.JtypeInstruction.returnSave,
            offset: offset
        }
    };
endfunction

//
// decode_jalr
//
function DecodedInstruction decode_jalr(EncodedInstruction encodedInstruction);
    return DecodedInstruction{
        instructionType: JALR,
        source1: encodedInstruction.ItypeInstruction.source1,
        source2: 0, // Unused
        specific: tagged JALRInstruction JALRInstruction{
            destination: encodedInstruction.ItypeInstruction.destination,
            offset: encodedInstruction.ItypeInstruction.immediate
        }
    };
endfunction

//
// decode_load
//
function DecodedInstruction decode_load(EncodedInstruction encodedInstruction);
    let loadOperator = case(encodedInstruction.ItypeInstruction.func3)
        3'b000: LB;
        3'b001: LH;
        3'b010: LW;
        3'b100: LBU;
        3'b101: LHU;
        default: UNSUPPORTED_LOAD_OPERATOR;
    endcase;

    if (loadOperator == UNSUPPORTED_LOAD_OPERATOR) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            source1: 0,
            source2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: LOAD,
            source1: encodedInstruction.RtypeInstruction.source1,
            source2: 0, // Unused
            specific: tagged LoadInstruction LoadInstruction{
                offset: encodedInstruction.ItypeInstruction.immediate,
                destination: encodedInstruction.ItypeInstruction.destination,
                operator: loadOperator
            }
        };    
    end
endfunction

//
// decode_lui
//
function DecodedInstruction decode_lui(EncodedInstruction encodedInstruction);
    Word effectiveAddress = 0;
    effectiveAddress[31:12] = encodedInstruction.UtypeInstruction.immediate31_12;

    return DecodedInstruction{
        instructionType: LUI,
        source1: 0, // Unused
        source2: 0, // Unused
        specific: tagged LUIInstruction LUIInstruction{
            destination: encodedInstruction.UtypeInstruction.destination,
            effectiveAddress: effectiveAddress
        }
    };
endfunction

//
// decode_op
//
function DecodedInstruction decode_op(EncodedInstruction encodedInstruction);
    // Assemble the alu operation code from the func3 and func7 fields of the instruction.
    Bit#(10) aluOperationCode = 0;
    aluOperationCode[2:0] = encodedInstruction.RtypeInstruction.func3;
    aluOperationCode[9:3] = encodedInstruction.RtypeInstruction.func7;

    let aluOperator = case(aluOperationCode)
        10'b0000000000: ADD;
        10'b0000000001: SLL;
        10'b0000000010: SLT;
        10'b0000000011: SLTU;
        10'b0000000100: XOR;
        10'b0000000101: SRL;
        10'b0000000110: OR;
        10'b0000000111: AND;
        10'b0100000000: SUB;
        10'b0100000101: SRA;
        default: UNSUPPORTED_ALU_OPERATOR;
    endcase;

    if (aluOperator == UNSUPPORTED_ALU_OPERATOR) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            source1: 0,
            source2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: OP,
            source1: encodedInstruction.RtypeInstruction.source1,
            source2: encodedInstruction.RtypeInstruction.source2,
            specific: tagged ALUInstruction ALUInstruction{
                destination: encodedInstruction.RtypeInstruction.destination,
                operator: aluOperator,
                immediate: 0 //Unused
            }
        };
    end
endfunction

//
// decode_opimm
//
function DecodedInstruction decode_opimm(EncodedInstruction encodedInstruction);
    let aluOperator = case(encodedInstruction.ItypeInstruction.func3)
        3'b000: ADDI;
        3'b010: SLTI;
        3'b011: SLTIU;
        3'b100: XORI;
        3'b110: ORI;
        3'b111: ANDI;
        default: UNSUPPORTED_ALU_OPERATOR;
    endcase;

    if (aluOperator == UNSUPPORTED_ALU_OPERATOR) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            source1: 0,
            source2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: OPIMM,
            source1: encodedInstruction.RtypeInstruction.source1,
            source2: 0, // Unused
            specific: tagged ALUInstruction ALUInstruction{
                destination: encodedInstruction.RtypeInstruction.destination,
                operator: aluOperator,
                immediate: signExtend(encodedInstruction.ItypeInstruction.immediate)
            }
        };
    end
endfunction

//
// decode_store
//
function DecodedInstruction decode_store(EncodedInstruction encodedInstruction);
    let storeOperator = case(encodedInstruction.StypeInstruction.func3)
        3'b000: SB;
        3'b001: SH;
        3'b010: SW;
        default: UNSUPPORTED_STORE_OPERATOR;
    endcase;

    if (storeOperator == UNSUPPORTED_STORE_OPERATOR) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            source1: 0,
            source2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        Bit#(12) offset;
        offset[11:5] = encodedInstruction.StypeInstruction.immediate11_5;
        offset[4:0] = encodedInstruction.StypeInstruction.immediate4_0;

        return DecodedInstruction{
            instructionType: STORE,
            source1: encodedInstruction.StypeInstruction.source1,
            source2: encodedInstruction.StypeInstruction.source2,
            specific: tagged StoreInstruction StoreInstruction{
                offset: offset,
                operator: storeOperator
            }
        };    
    end
endfunction
