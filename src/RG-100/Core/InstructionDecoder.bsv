import ALU::*;
import FIFOF::*;
import RVTypes::*;
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
//
// decode_auipc
//
function DecodedInstruction decode_auipc(UtypeInstruction uTypeInstruction);
    Word offset = 0;
    offset[31:12] = uTypeInstruction.immediate31_12;

    return DecodedInstruction{
        instructionType: AUIPC,
        rs1: 0, // Unused
        rs2: 0, // Unused
        specific: tagged AUIPCInstruction AUIPCInstruction{
            rd: uTypeInstruction.rd,
            offset: offset
        }
    };
endfunction

//
// decode_branch
//
function DecodedInstruction decode_branch(BtypeInstruction bTypeInstruction);
    Bit#(13) offset = 0;
    offset[12] = bTypeInstruction.immediate12;
    offset[11] = bTypeInstruction.immediate11;
    offset[10:5] = bTypeInstruction.immediate10_5;
    offset[4:1] = bTypeInstruction.immediate4_1;

    let branchOperator = case(bTypeInstruction.func3)
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
            rs1: 0,
            rs2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: BRANCH,
            rs1: bTypeInstruction.rs1,
            rs2: bTypeInstruction.rs2,
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
function DecodedInstruction decode_jal(JtypeInstruction jTypeInstruction);
    Bit#(21) offset = 0;
    offset[20] = jTypeInstruction.immediate20;
    offset[19:12] = jTypeInstruction.immediate19_12;
    offset[11] = jTypeInstruction.immediate11;
    offset[10:1] = jTypeInstruction.immediate10_1;
    offset[0] = 0;

    return DecodedInstruction{
        instructionType: JAL,
        rs1: 0, // Unused
        rs2: 0, // Unused
        specific: tagged JALInstruction JALInstruction{
            rd: jTypeInstruction.returnSave,
            offset: offset
        }
    };
endfunction

//
// decode_jalr
//
function DecodedInstruction decode_jalr(ItypeInstruction iTypeInstruction);
    return DecodedInstruction{
        instructionType: JALR,
        rs1: iTypeInstruction.rs1,
        rs2: 0, // Unused
        specific: tagged JALRInstruction JALRInstruction{
            rd: iTypeInstruction.rd,
            offset: iTypeInstruction.immediate
        }
    };
endfunction

//
// decode_load
//
function DecodedInstruction decode_load(ItypeInstruction iTypeInstruction);
    let loadOperator = case(iTypeInstruction.func3)
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
            rs1: 0,
            rs2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        return DecodedInstruction{
            instructionType: LOAD,
            rs1: iTypeInstruction.rs1,
            rs2: 0, // Unused
            specific: tagged LoadInstruction LoadInstruction{
                offset: iTypeInstruction.immediate,
                rd: iTypeInstruction.rd,
                operator: loadOperator
            }
        };    
    end
endfunction

//
// decode_lui
//
function DecodedInstruction decode_lui(UtypeInstruction uTypeInstruction);
    return DecodedInstruction{
        instructionType: LUI,
        rs1: 0, // Unused
        rs2: 0, // Unused
        specific: tagged LUIInstruction LUIInstruction{
            rd: uTypeInstruction.rd,
            immediate: uTypeInstruction.immediate31_12
        }
    };
endfunction

//
// decode_op
//
function DecodedInstruction decode_op(RtypeInstruction rTypeInstruction);
    // Assemble the alu operation code from the func3 and func7 fields of the instruction.
    let aluOperator = case(rTypeInstruction.func3)
        3'b000: (rTypeInstruction.func7[6] == 0 ? ADD : SUB);
        3'b001: SLL;
        3'b010: SLT;
        3'b011: SLTU;
        3'b100: XOR;
        3'b101: (rTypeInstruction.func7[6] == 0 ? SRL : SRA);
        3'b110: OR;
        3'b111: AND;
    endcase;

    return DecodedInstruction{
        instructionType: OP,
        rs1: rTypeInstruction.rs1,
        rs2: rTypeInstruction.rs2,
        specific: tagged ALUInstruction ALUInstruction{
            rd: rTypeInstruction.rd,
            operator: aluOperator,
            immediate: 0 //Unused
        }
    };
endfunction

//
// decode_opimm
//
function DecodedInstruction decode_opimm(ItypeInstruction iTypeInstruction);
    let aluOperator = case(iTypeInstruction.func3)
        3'b000: ADD;
        3'b001: SLL;
        3'b010: SLT;
        3'b011: SLTU;
        3'b100: XOR;
        3'b101: (iTypeInstruction.immediate[10] == 0 ? SRL : SRA);
        3'b110: OR;
        3'b111: AND;
    endcase;

    let immediate = iTypeInstruction.immediate;
    if (aluOperator == SRA) begin
        immediate[10] = 0;
    end

    return DecodedInstruction{
        instructionType: OPIMM,
        rs1: iTypeInstruction.rs1,
        rs2: 0, // Unused
        specific: tagged ALUInstruction ALUInstruction{
            rd: iTypeInstruction.rd,
            operator: aluOperator,
            immediate: immediate
        }
    };
endfunction

//
// decode_store
//
function DecodedInstruction decode_store(StypeInstruction sTypeInstruction);
    let storeOperator = case(sTypeInstruction.func3)
        3'b000: SB;
        3'b001: SH;
        3'b010: SW;
        default: UNSUPPORTED_STORE_OPERATOR;
    endcase;

    if (storeOperator == UNSUPPORTED_STORE_OPERATOR) begin
        return DecodedInstruction{
            instructionType: UNSUPPORTED,
            rs1: 0,
            rs2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    end else begin
        Bit#(12) offset;
        offset[11:5] = sTypeInstruction.immediate11_5;
        offset[4:0] = sTypeInstruction.immediate4_0;

        return DecodedInstruction{
            instructionType: STORE,
            rs1: sTypeInstruction.rs1,
            rs2: sTypeInstruction.rs2,
            specific: tagged StoreInstruction StoreInstruction{
                offset: offset,
                operator: storeOperator
            }
        };    
    end
endfunction

//
// decode_system
//
function DecodedInstruction decode_system(ItypeInstruction iTypeInstruction);
    return case({iTypeInstruction.immediate, iTypeInstruction.rs1, iTypeInstruction.func3, iTypeInstruction.rd})
        25'b000000000000_00000_000_00000: begin
            DecodedInstruction{
                instructionType: SYSTEM,
                rs1: 0,     // Unused
                rs2: 0,     // Unused
                specific: tagged SystemInstruction SystemInstruction{
                    operator: ECALL
                }
            };
        end
        25'b000000000001_00000_000_00000: begin
            DecodedInstruction{
                instructionType: SYSTEM,
                rs1: 0,     // Unused
                rs2: 0,     // Unused
                specific: tagged SystemInstruction SystemInstruction{
                    operator: EBREAK
                }
            };
        end
        default: begin
            DecodedInstruction{
                instructionType: UNSUPPORTED,
                rs1: 0,     // Unused
                rs2: 0,     // Unused
                specific: tagged UnsupportedInstruction UnsupportedInstruction{}
            };
        end
    endcase;
endfunction

function DecodedInstruction decodeInstruction(Word rawInstruction);
    BtypeInstruction bTypeInstruction = unpack(rawInstruction);
    ItypeInstruction iTypeInstruction = unpack(rawInstruction);
    JtypeInstruction jTypeInstruction = unpack(rawInstruction);
    RtypeInstruction rTypeInstruction = unpack(rawInstruction);
    StypeInstruction sTypeInstruction = unpack(rawInstruction);
    UtypeInstruction uTypeInstruction = unpack(rawInstruction);

    return case(rawInstruction[6:0])
        // RV32I
        7'b0000011: decode_load(iTypeInstruction);      // LOAD     (I-type)
        7'b0010011: decode_opimm(iTypeInstruction);     // OPIMM    (I-type)
        7'b0010111: decode_auipc(uTypeInstruction);     // AUIPC    (U-type)
        7'b0100011: decode_store(sTypeInstruction);     // STORE    (S-type)
        7'b0110011: decode_op(rTypeInstruction);        // OP       (R-type)
        7'b0110111: decode_lui(uTypeInstruction);       // LUI      (U-type)
        7'b1100011: decode_branch(bTypeInstruction);    // BRANCH   (B-type)
        7'b1100111: decode_jalr(iTypeInstruction);      // JALR     (I-type)
        7'b1101111: decode_jal(jTypeInstruction);       // JAL      (J-type)
        7'b1110011: decode_system(iTypeInstruction);    // SYSTEM   (I-type)
        default: DecodedInstruction{
            instructionType: UNSUPPORTED,
            rs1: 0,
            rs2: 0,
            specific: tagged UnsupportedInstruction UnsupportedInstruction{}
        };
    endcase;
endfunction

interface InstructionDecoder;
endinterface

module mkInstructionDecoder#(
    FIFOF#(Word32) instructionQueue,
    FIFOF#(DecodedInstruction) outputQueue
)(InstructionDecoder);
    rule decode;
        let encodedInstruction = instructionQueue.first();
        instructionQueue.deq();

        let decodedInstruction = decodeInstruction(encodedInstruction);
        outputQueue.enq(decodedInstruction);
    endrule
endmodule
