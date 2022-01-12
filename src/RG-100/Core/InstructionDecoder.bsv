import RVOperandForward::*;
import RVTypes::*;
import RVRegisterFile::*;
import RVInstruction::*;
import RVALU::*;

import Instruction::*;

// ================================================================
// Exports
export InstructionDecoder (..), mkInstructionDecoder;

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

interface InstructionDecoder;
    method Maybe#(DecodedInstruction) decode(Word programCounter, Word encodedInstruction);
endinterface

module mkInstructionDecoder#(
    RVRegisterFile registerFile,
    RWire#(RVOperandForward) operandForward1,
    RWire#(RVOperandForward) operandForward2
)(InstructionDecoder);
    // 
    // readRegister() - also check any operand forwarding.
    //
    function Maybe#(Word) readOperandForwards(Word registerValue, RegisterIndex rx);
        let valueResult = tagged Valid registerValue;

        // If necessary, check forwarded operands from later stages
        if (rx != 0) begin
            if (operandForward1.wget() matches tagged Valid .of) begin
                if (of.rd == rx) begin
                    if (isValid(of.value)) begin
                        valueResult = of.value;
                    end else begin
                        valueResult = tagged Invalid;
                    end
                end
            end

            // Check bypassB
            if (operandForward2.wget() matches tagged Valid .of) begin
                if (of.rd == rx) begin
                    if (isValid(of.value)) begin
                        valueResult = of.value;
                    end else begin
                        valueResult = tagged Invalid;
                    end
                end
            end
        end

        return valueResult;
    endfunction

    function Maybe#(Word) readRegister1(RegisterIndex rx);
        return readOperandForwards(registerFile.read1(rx), rx);
    endfunction

    function Maybe#(Word) readRegister2(RegisterIndex rx);
        return readOperandForwards(registerFile.read2(rx), rx);
    endfunction

    //
    // predict_branch
    //
    function Bool predict_branch(Word currentProgramCounter, Word targetAddress);
        // Simple static branch predictor
        // Predicted taken if target address is smaller than the program counter
        // (backward branch), otherwise (forward branch) predicted not taken.
        return (targetAddress < currentProgramCounter ? True : False);
    endfunction

    //
    // decode_auipc
    //
    function Maybe#(DecodedInstruction) decode_auipc(Word programCounter, UtypeInstruction uTypeInstruction);
        Word offset = 0;
        offset[31:12] = uTypeInstruction.immediate31_12;

        return tagged Valid DecodedInstruction{
            programCounter: programCounter,
            nextProgramCounter: programCounter + 4,
            instructionType: AUIPC,
            rs1: ?,
            rs2: ?,
            specific: tagged AUIPCInstruction AUIPCInstruction{
                rd: uTypeInstruction.rd,
                offset: offset
            }
        };
    endfunction

    //
    // decode_branch
    //
    function Maybe#(DecodedInstruction) decode_branch(Word programCounter, BtypeInstruction bTypeInstruction);
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
            return tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: programCounter,
                instructionType: UNSUPPORTED,
                rs1: ?,
                rs2: ?,
                specific: tagged UnsupportedInstruction UnsupportedInstruction{}
            };
        end else begin
            let result = tagged Invalid;

            // Branch prediction (the signed offset is relative to rs1 but since
            // that's not available, we ignore it)
            let targetAddress = programCounter + signExtend(offset);
            let isTaken = predict_branch(programCounter, targetAddress);
            let nextProgramCounter = (isTaken ? targetAddress : programCounter + 4);

            return tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: nextProgramCounter,
                instructionType: BRANCH,
                rs1: ?,
                rs2: ?,
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
    function Maybe#(DecodedInstruction) decode_jal(Word programCounter, JtypeInstruction jTypeInstruction);
        Bit#(21) offset = 0;
        offset[20] = jTypeInstruction.immediate20;
        offset[19:12] = jTypeInstruction.immediate19_12;
        offset[11] = jTypeInstruction.immediate11;
        offset[10:1] = jTypeInstruction.immediate10_1;
        offset[0] = 0;

        return tagged Valid DecodedInstruction{
            programCounter: programCounter,
            nextProgramCounter: programCounter + signExtend(offset * 2),
            instructionType: JAL,
            rs1: ?,
            rs2: ?,
            specific: tagged JALInstruction JALInstruction{
                rd: jTypeInstruction.returnSave,
                offset: offset
            }
        };
    endfunction

    //
    // decode_jalr
    //
    function Maybe#(DecodedInstruction) decode_jalr(Word programCounter, ItypeInstruction iTypeInstruction);
        // NOTE: This might stall the pipeline if the register
        //       isn't available. 
        let registerReadResult = readRegister1(iTypeInstruction.rs1);

        if (isValid(registerReadResult) == False) begin
            return tagged Invalid;
        end else begin
            let rs1 = fromMaybe(?, registerReadResult);
            let targetAddress = rs1 + signExtend(iTypeInstruction.immediate);
            targetAddress[0] = 0;

            return tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: targetAddress,
                instructionType: JALR,
                rs1: rs1,
                rs2: ?,
                specific: tagged JALRInstruction JALRInstruction{
                    rd: iTypeInstruction.rd,
                    offset: iTypeInstruction.immediate
                }
            };
        end
    endfunction

    //
    // decode_load
    //
    function Maybe#(DecodedInstruction) decode_load(Word programCounter, ItypeInstruction iTypeInstruction);
        let loadOperator = case(iTypeInstruction.func3)
            3'b000: LB;
            3'b001: LH;
            3'b010: LW;
            3'b100: LBU;
            3'b101: LHU;
            default: UNSUPPORTED_LOAD_OPERATOR;
        endcase;

        let nextProgramCounter = programCounter + 4;

        if (loadOperator == UNSUPPORTED_LOAD_OPERATOR) begin
            return tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: nextProgramCounter,
                instructionType: UNSUPPORTED,
                rs1: ?,
                rs2: ?,
                specific: tagged UnsupportedInstruction UnsupportedInstruction{}
            };
        end else begin
            // NOTE: This might stall the pipeline if the register
            //       isn't available. 
            let registerReadResult = readRegister1(iTypeInstruction.rs1);
            if (isValid(registerReadResult) == False) begin
                return tagged Invalid;
            end else begin
                let rs1 = fromMaybe(?, registerReadResult);

                return tagged Valid DecodedInstruction{
                    programCounter: programCounter,
                    nextProgramCounter: nextProgramCounter,
                    instructionType: LOAD,  
                    rs1: rs1,
                    rs2: ?,
                    specific: tagged LoadInstruction LoadInstruction{
                        offset: iTypeInstruction.immediate,
                        rd: iTypeInstruction.rd,
                        operator: loadOperator
                    }
                };
            end
        end
    endfunction

    //
    // decode_lui
    //
    function Maybe#(DecodedInstruction) decode_lui(Word programCounter, UtypeInstruction uTypeInstruction);
        return tagged Valid DecodedInstruction{
            programCounter: programCounter,
            nextProgramCounter: programCounter + 4,
            instructionType: LUI,
            rs1: ?,
            rs2: ?,
            specific: tagged LUIInstruction LUIInstruction{
                rd: uTypeInstruction.rd,
                immediate: uTypeInstruction.immediate31_12
            }
        };
    endfunction

    //
    // decode_op
    //
    function Maybe#(DecodedInstruction) decode_op(Word programCounter, RtypeInstruction rTypeInstruction);
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

        // NOTE: This might stall the pipeline if the register
        //       isn't available. 
        let rs1Result = readRegister1(rTypeInstruction.rs1);
        let rs2Result = readRegister2(rTypeInstruction.rs2);

        if (isValid(rs1Result) == False || isValid(rs2Result) == False) begin
            return tagged Invalid;
        end else begin
            return tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: programCounter + 4,
                instructionType: OP,
                rs1: fromMaybe(?, rs1Result),
                rs2: fromMaybe(?, rs2Result),
                specific: tagged ALUInstruction ALUInstruction{
                    rd: rTypeInstruction.rd,
                    operator: aluOperator,
                    immediate: ?
                }
            };
        end
    endfunction

    //
    // decode_opimm
    //
    function Maybe#(DecodedInstruction) decode_opimm(Word programCounter, ItypeInstruction iTypeInstruction);
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

        let rs1Result = readRegister1(iTypeInstruction.rs1);
        if (isValid(rs1Result) == False) begin
            return tagged Invalid;
        end else begin
            return tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: programCounter + 4,
                instructionType: OPIMM,
                rs1: fromMaybe(?, rs1Result),
                rs2: ?,
                specific: tagged ALUInstruction ALUInstruction{
                    rd: iTypeInstruction.rd,
                    operator: aluOperator,
                    immediate: immediate
                }
            };
        end
    endfunction

    //
    // decode_store
    //
    function Maybe#(DecodedInstruction) decode_store(Word programCounter, StypeInstruction sTypeInstruction);
        let storeOperator = case(sTypeInstruction.func3)
            3'b000: SB;
            3'b001: SH;
            3'b010: SW;
            default: UNSUPPORTED_STORE_OPERATOR;
        endcase;

        if (storeOperator == UNSUPPORTED_STORE_OPERATOR) begin
            return tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: programCounter + 4,
                instructionType: UNSUPPORTED,
                rs1: ?,
                rs2: ?,
                specific: tagged UnsupportedInstruction UnsupportedInstruction{}
            };
        end else begin
            // NOTE: This might stall the pipeline if the register
            //       isn't available. 
            let rs1Result = readRegister1(sTypeInstruction.rs1);
            let rs2Result = readRegister2(sTypeInstruction.rs2);

            if (isValid(rs1Result) == False || isValid(rs2Result) == False) begin
                return tagged Invalid;
            end else begin
                Bit#(12) offset;
                offset[11:5] = sTypeInstruction.immediate11_5;
                offset[4:0] = sTypeInstruction.immediate4_0;

                return tagged Valid DecodedInstruction{
                    programCounter: programCounter,
                    nextProgramCounter: programCounter + 4,
                    instructionType: STORE,
                    rs1: fromMaybe(?, rs1Result),
                    rs2: fromMaybe(?, rs2Result),
                    specific: tagged StoreInstruction StoreInstruction{
                        offset: offset,
                        operator: storeOperator
                    }
                };
            end
        end
    endfunction

    //
    // decode_system
    //
    function Maybe#(DecodedInstruction) decode_system(Word programCounter, ItypeInstruction iTypeInstruction);
        return case({iTypeInstruction.immediate, iTypeInstruction.rs1, iTypeInstruction.func3, iTypeInstruction.rd})
            25'b000000000000_00000_000_00000: begin
                tagged Valid DecodedInstruction{
                    programCounter: programCounter,
                    nextProgramCounter: programCounter + 4,
                    instructionType: SYSTEM,
                    rs1: ?,
                    rs2: ?,
                    specific: tagged SystemInstruction SystemInstruction{
                        operator: ECALL
                    }
                };
            end
            25'b000000000001_00000_000_00000: begin
                tagged Valid DecodedInstruction{
                    programCounter: programCounter,
                    nextProgramCounter: programCounter + 4,
                    instructionType: SYSTEM,
                    rs1: ?,
                    rs2: ?,
                    specific: tagged SystemInstruction SystemInstruction{
                        operator: EBREAK
                    }
                };
            end
            default: begin
                tagged Valid DecodedInstruction{
                    programCounter: programCounter,
                    nextProgramCounter: programCounter + 4,
                    instructionType: UNSUPPORTED,
                    rs1: ?,
                    rs2: ?,
                    specific: tagged UnsupportedInstruction UnsupportedInstruction{}
                };
            end
        endcase;
    endfunction

    function Maybe#(DecodedInstruction) decodeInstruction(Word programCounter, Word encodedInstruction);
        BtypeInstruction bTypeInstruction = unpack(encodedInstruction);
        ItypeInstruction iTypeInstruction = unpack(encodedInstruction);
        JtypeInstruction jTypeInstruction = unpack(encodedInstruction);
        RtypeInstruction rTypeInstruction = unpack(encodedInstruction);
        StypeInstruction sTypeInstruction = unpack(encodedInstruction);
        UtypeInstruction uTypeInstruction = unpack(encodedInstruction);

        return case(encodedInstruction[6:0])
            // RV32I
            7'b0000011: decode_load(programCounter, iTypeInstruction);      // LOAD     (I-type)
            7'b0010011: decode_opimm(programCounter, iTypeInstruction);     // OPIMM    (I-type)
            7'b0010111: decode_auipc(programCounter, uTypeInstruction);     // AUIPC    (U-type)
            7'b0100011: decode_store(programCounter, sTypeInstruction);     // STORE    (S-type)
            7'b0110011: decode_op(programCounter, rTypeInstruction);        // OP       (R-type)
            7'b0110111: decode_lui(programCounter, uTypeInstruction);       // LUI      (U-type)
            7'b1100011: decode_branch(programCounter, bTypeInstruction);    // BRANCH   (B-type)
            7'b1100111: decode_jalr(programCounter, iTypeInstruction);      // JALR     (I-type)
            7'b1101111: decode_jal(programCounter, jTypeInstruction);       // JAL      (J-type)
            7'b1110011: decode_system(programCounter, iTypeInstruction);    // SYSTEM   (I-type)
            default: tagged Valid DecodedInstruction{
                programCounter: programCounter,
                nextProgramCounter: programCounter + 4,
                instructionType: UNSUPPORTED,
                rs1: ?,
                rs2: ?,
                specific: tagged UnsupportedInstruction UnsupportedInstruction{}
            };
        endcase;
    endfunction

    method Maybe#(DecodedInstruction) decode(Word programCounter, Word encodedInstruction);
        return decodeInstruction(programCounter, encodedInstruction);
    endmethod
endmodule
