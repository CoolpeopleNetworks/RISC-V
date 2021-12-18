import ALU::*;
import FIFOF::*;
import RVRegisterBypass::*;
import RVRegisterFile::*;
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

interface InstructionDecoder;
endinterface

module mkInstructionDecoder#(
    FIFOF#(Tuple2#(ProgramCounter, Word32)) instructionQueue,
    RVRegisterFile registerFile,
    Wire#(RVRegisterBypass) bypassA,
    Wire#(RVRegisterBypass) bypassB,
    FIFOF#(DecodedInstruction) outputQueue,
    Reg#(ProgramCounter) nextProgramCounter     // <- Modified for next instruction.
)(InstructionDecoder);

    function Maybe#(Word) readRegister(RegisterIndex rx);
        // First, read the register.
        let value = registerFile.read1(rx);
        let valueResult = tagged Valid value;

        if (rx != 0) begin
            // Check bypassA
            if (bypassA.rd == rx) begin
                if (isValid(bypassA.value)) begin
                    valueResult = bypassA.value;
                end else begin
                    valueResult = tagged Invalid;
                end
            end

            // Check bypassB
            if (bypassB.rd == rx) begin
                if (isValid(bypassB.value)) begin
                    valueResult = bypassB.value;
                end else begin
                    valueResult = tagged Invalid;
                end
            end
        end
        
        return valueResult;
    endfunction

    //
    // decode_auipc
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_auipc(ProgramCounter programCounter, UtypeInstruction uTypeInstruction);
        Word offset = 0;
        offset[31:12] = uTypeInstruction.immediate31_12;

        return tuple2(
            DecodedInstruction{
                programCounter: programCounter,
                instructionType: AUIPC,
                rs1: 0, // Unused
                rs2: 0, // Unused
                specific: tagged AUIPCInstruction AUIPCInstruction{
                    rd: uTypeInstruction.rd,
                    offset: offset
                }
            }, programCounter + 4);
    endfunction

    //
    // decode_branch
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_branch(ProgramCounter programCounter, BtypeInstruction bTypeInstruction, Word rs1, Word rs2);
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

        // TODO: calculate branch target
        let nextProgramCounter = programCounter;  // This will stall the pipeline

        if (branchOperator == UNSUPPORTED_BRANCH_OPERATOR) begin
            return tuple2(
                DecodedInstruction{
                    programCounter: programCounter,
                    instructionType: UNSUPPORTED,
                    rs1: 0,
                    rs2: 0,
                    specific: tagged UnsupportedInstruction UnsupportedInstruction{}
                }, programCounter + 4
            );
        end else begin
            return tuple2(
                DecodedInstruction{
                    programCounter: programCounter,
                    instructionType: BRANCH,
                    rs1: rs1,
                    rs2: rs2,
                    specific: tagged BranchInstruction BranchInstruction{
                        offset: offset,
                        operator: branchOperator
                    }
                }, nextProgramCounter
            );
        end
    endfunction

    //
    // decode_jal
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_jal(ProgramCounter programCounter, JtypeInstruction jTypeInstruction);
        Bit#(21) offset = 0;
        offset[20] = jTypeInstruction.immediate20;
        offset[19:12] = jTypeInstruction.immediate19_12;
        offset[11] = jTypeInstruction.immediate11;
        offset[10:1] = jTypeInstruction.immediate10_1;
        offset[0] = 0;

        // TODO: Fix - this will stall the pipeline.
        let nextProgramCounter = programCounter;

        return tuple2(
            DecodedInstruction{
                programCounter: programCounter,
                instructionType: JAL,
                rs1: 0, // Unused
                rs2: 0, // Unused
                specific: tagged JALInstruction JALInstruction{
                    rd: jTypeInstruction.returnSave,
                    offset: offset
                }
            }, nextProgramCounter
        );
    endfunction

    //
    // decode_jalr
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_jalr(ProgramCounter programCounter, ItypeInstruction iTypeInstruction, Word rs1);
        // TODO: calculate program counter - this will stall.
        let nextProgramCounter = programCounter;

        return tuple2(
            DecodedInstruction{
                programCounter: programCounter,
                instructionType: JALR,
                rs1: rs1,
                rs2: 0, // Unused
                specific: tagged JALRInstruction JALRInstruction{
                    rd: iTypeInstruction.rd,
                    offset: iTypeInstruction.immediate
                }
            }, nextProgramCounter
        );
    endfunction

    //
    // decode_load
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_load(ProgramCounter programCounter, ItypeInstruction iTypeInstruction, Word rs1);
        let loadOperator = case(iTypeInstruction.func3)
            3'b000: LB;
            3'b001: LH;
            3'b010: LW;
            3'b100: LBU;
            3'b101: LHU;
            default: UNSUPPORTED_LOAD_OPERATOR;
        endcase;

        if (loadOperator == UNSUPPORTED_LOAD_OPERATOR) begin
            return tuple2(
                DecodedInstruction{
                    programCounter: programCounter,
                    instructionType: UNSUPPORTED,
                    rs1: 0,
                    rs2: 0,
                    specific: tagged UnsupportedInstruction UnsupportedInstruction{}
                }, programCounter + 4
            );
        end else begin
            return tuple2(
                DecodedInstruction{
                    programCounter: programCounter,
                    instructionType: LOAD,
                    rs1: rs1,
                    rs2: 0, // Unused
                    specific: tagged LoadInstruction LoadInstruction{
                        offset: iTypeInstruction.immediate,
                        rd: iTypeInstruction.rd,
                        operator: loadOperator
                    }
                }, programCounter + 4
            );
        end
    endfunction

    //
    // decode_lui
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_lui(ProgramCounter programCounter, UtypeInstruction uTypeInstruction);
        return tuple2(
            DecodedInstruction{
                programCounter: programCounter,
                instructionType: LUI,
                rs1: 0, // Unused
                rs2: 0, // Unused
                specific: tagged LUIInstruction LUIInstruction{
                    rd: uTypeInstruction.rd,
                    immediate: uTypeInstruction.immediate31_12
                }
            }, programCounter + 4
        );
    endfunction

    //
    // decode_op
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_op(ProgramCounter programCounter, RtypeInstruction rTypeInstruction, Word rs1, Word rs2);
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

        return tuple2(
            DecodedInstruction{
                programCounter: programCounter,
                instructionType: OP,
                rs1: rs1,
                rs2: rs2,
                specific: tagged ALUInstruction ALUInstruction{
                    rd: rTypeInstruction.rd,
                    operator: aluOperator,
                    immediate: 0 //Unused
                }
            }, programCounter + 4
        );
    endfunction

    //
    // decode_opimm
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_opimm(ProgramCounter programCounter, ItypeInstruction iTypeInstruction, Word rs1);
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

        return tuple2(
            DecodedInstruction{
                programCounter: programCounter,
                instructionType: OPIMM,
                rs1: rs1,
                rs2: 0, // Unused
                specific: tagged ALUInstruction ALUInstruction{
                    rd: iTypeInstruction.rd,
                    operator: aluOperator,
                    immediate: immediate
                }
            }, programCounter + 4
        );
    endfunction

    //
    // decode_store
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_store(ProgramCounter programCounter, StypeInstruction sTypeInstruction, Word rs1, Word rs2);
        let storeOperator = case(sTypeInstruction.func3)
            3'b000: SB;
            3'b001: SH;
            3'b010: SW;
            default: UNSUPPORTED_STORE_OPERATOR;
        endcase;

        if (storeOperator == UNSUPPORTED_STORE_OPERATOR) begin
            return tuple2(
                DecodedInstruction{
                programCounter: programCounter,
                instructionType: UNSUPPORTED,
                rs1: 0,
                rs2: 0,
                specific: tagged UnsupportedInstruction UnsupportedInstruction{}
                }, programCounter + 4
            );
        end else begin
            Bit#(12) offset;
            offset[11:5] = sTypeInstruction.immediate11_5;
            offset[4:0] = sTypeInstruction.immediate4_0;

            return tuple2(
                DecodedInstruction{
                    programCounter: programCounter,
                    instructionType: STORE,
                    rs1: rs1,
                    rs2: rs2,
                    specific: tagged StoreInstruction StoreInstruction{
                        offset: offset,
                        operator: storeOperator
                    }
                }, programCounter + 4
            );
        end
    endfunction

    //
    // decode_system
    //
    function Tuple2#(DecodedInstruction, ProgramCounter) decode_system(ProgramCounter programCounter, ItypeInstruction iTypeInstruction, Word rs1);
        return case({iTypeInstruction.immediate, iTypeInstruction.rs1, iTypeInstruction.func3, iTypeInstruction.rd})
            25'b000000000000_00000_000_00000: begin
                tuple2(
                    DecodedInstruction{
                        programCounter: programCounter,
                        instructionType: SYSTEM,
                        rs1: 0,     // Unused
                        rs2: 0,     // Unused
                        specific: tagged SystemInstruction SystemInstruction{
                            operator: ECALL
                        }
                    }, programCounter + 4
                );
            end
            25'b000000000001_00000_000_00000: begin
                tuple2(
                    DecodedInstruction{
                        programCounter: programCounter,
                        instructionType: SYSTEM,
                        rs1: 0,     // Unused
                        rs2: 0,     // Unused
                        specific: tagged SystemInstruction SystemInstruction{
                            operator: EBREAK
                        }
                    }, programCounter + 4
                );
            end
            default: begin
                tuple2(
                    DecodedInstruction{
                        programCounter: programCounter,
                        instructionType: UNSUPPORTED,
                        rs1: 0,     // Unused
                        rs2: 0,     // Unused
                        specific: tagged UnsupportedInstruction UnsupportedInstruction{}
                    }, programCounter + 4
                );
            end
        endcase;
    endfunction

    function Tuple2#(DecodedInstruction, ProgramCounter) decodeInstruction(ProgramCounter programCounter, Word rawInstruction, Word rs1, Word rs2);
        BtypeInstruction bTypeInstruction = unpack(rawInstruction);
        ItypeInstruction iTypeInstruction = unpack(rawInstruction);
        JtypeInstruction jTypeInstruction = unpack(rawInstruction);
        RtypeInstruction rTypeInstruction = unpack(rawInstruction);
        StypeInstruction sTypeInstruction = unpack(rawInstruction);
        UtypeInstruction uTypeInstruction = unpack(rawInstruction);

        return case(rawInstruction[6:0])
            // RV32I
            7'b0000011: decode_load(programCounter, iTypeInstruction, rs1);         // LOAD     (I-type)
            7'b0010011: decode_opimm(programCounter, iTypeInstruction, rs1);        // OPIMM    (I-type)
            7'b0010111: decode_auipc(programCounter, uTypeInstruction);             // AUIPC    (U-type)
            7'b0100011: decode_store(programCounter, sTypeInstruction, rs1, rs2);   // STORE    (S-type)
            7'b0110011: decode_op(programCounter, rTypeInstruction, rs1, rs2);      // OP       (R-type)
            7'b0110111: decode_lui(programCounter, uTypeInstruction);               // LUI      (U-type)
            7'b1100011: decode_branch(programCounter, bTypeInstruction, rs1, rs2);  // BRANCH   (B-type)
            7'b1100111: decode_jalr(programCounter, iTypeInstruction, rs1);         // JALR     (I-type)
            7'b1101111: decode_jal(programCounter, jTypeInstruction);               // JAL      (J-type)
            7'b1110011: decode_system(programCounter, iTypeInstruction, rs1);       // SYSTEM   (I-type)
            default: tuple2(
                DecodedInstruction{
                    programCounter: programCounter,
                    instructionType: UNSUPPORTED,
                    rs1: 0,
                    rs2: 0,
                    specific: tagged UnsupportedInstruction UnsupportedInstruction{}
                }, programCounter + 4
            );
        endcase;
    endfunction

    rule decode;
        // Extract the program co0unter and encoded instruction from the queue.

        // NOTE: The item isn't dequeued until the register reads succeed.  This 
        //       will stall the pipeline while waiting for register reads that have
        //       to go to main memory.
        let queueItem = instructionQueue.first();

        let encodedInstruction = tpl_2(queueItem);

        // Extract RS1 and RS2 indices from the instruction.   For some instructions,
        // this will be unnecessary (or even correct) but reading them now will have
        // no affect in those cases.
        let rs1Index = encodedInstruction[19:15];
        let rs2Index = encodedInstruction[24:20];

        // Read the RS1 and RS2 registers.  It's possible the data in the registers
        // isn't available yet (if coming from a memory access).  If that's the case
        // the pipeline will stall.
        let rs1ReadResult = readRegister(rs1Index);
        let rs2ReadResult = readRegister(rs2Index);

        if (isValid(rs1ReadResult) != False && isValid(rs2ReadResult) != False) begin
            instructionQueue.deq();

            let programCounter = tpl_1(queueItem);
            let rs1 = fromMaybe(?, rs1ReadResult);
            let rs2 = fromMaybe(?, rs2ReadResult);

            // Decode the instruction returning that as well as the next program counter.
            let decodeResult = decodeInstruction(programCounter, encodedInstruction, rs1, rs2);
            nextProgramCounter <= tpl_2(decodeResult);

            // Send the current program counter and decode result to the output queue.
            outputQueue.enq(tpl_1(decodeResult));
        end
    endrule
endmodule
