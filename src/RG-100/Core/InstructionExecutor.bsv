import ALU::*;
import FIFOF::*;
import RVRegisterFile::*;
import RVTypes::*;
import Instruction::*;

interface InstructionExecutor;
    method Action enableTracing();
endinterface

module mkInstructionExecutor#(
    Reg#(ProgramCounter) programCounter, 
    RVRegisterFile registerFile,
    FIFOF#(DecodedInstruction) decodedInstructionQueue,
    FIFOF#(ExecutedInstruction) outputQueue
)(InstructionExecutor);
    Reg#(Bool) trace <- mkReg(False);

    //
    // ALU
    //
    ALU alu <- mkALU();

    //
    // AUIPC
    //
    function ExecutedInstruction executeAUIPCInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: currentPc + 4,
            writeBack: decodedInstruction.specific.AUIPCInstruction.rd,
            writeBackData: currentPc + decodedInstruction.specific.AUIPCInstruction.offset,

            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // BRANCH
    //
    function Bool branchTaken(Word a, Word b, BranchOperator op);
        return case(op)
            BEQ: (a == b);
            BNE: (a != b);
            BLT: signedLT(a, b);
            BLTU: (a < b);
            BGE: signedGE(a, b);
            BGEU: (a >= b);
        endcase;
    endfunction

    function ExecutedInstruction executeBRANCHInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
        let nextPc = currentPc + 4;
        if (branchTaken(rs1, rs2, decodedInstruction.specific.BranchInstruction.operator)) begin
            nextPc = currentPc + signExtend(decodedInstruction.specific.BranchInstruction.offset);

            if ((nextPc & 'h3) != 0) begin
                // BUGBUG: handle misaligne branch.
            end
        end

        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: nextPc,
            writeBack: 0,           // Unused
            writeBackData: 0,       // Unused
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // JAL
    //
    function ExecutedInstruction executeJALInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: currentPc + signExtend(decodedInstruction.specific.JALInstruction.offset),
            writeBack: decodedInstruction.specific.JALInstruction.rd,
            writeBackData: currentPc + 4,
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // JALR
    //
    function ExecutedInstruction executeJALRInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1);
        let immediate = signExtend(decodedInstruction.specific.JALRInstruction.offset);
        let effectiveAddress = rs1 + immediate;
        effectiveAddress[0] = 0;

        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: effectiveAddress,
            writeBack: decodedInstruction.specific.JALRInstruction.rd,
            writeBackData: currentPc + 4,
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // LOAD
    //
    function ExecutedInstruction executeLOADInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
        let misaligned = False;
        let effectiveAddress = 0;
        Bit#(4) byteMask = 0;
        let operator = decodedInstruction.specific.LoadInstruction.operator;
        case(operator)
            LB, LBU: begin
                let directAddress = (operator == LB ? 
                    rs1 + signExtend(decodedInstruction.specific.LoadInstruction.offset) :
                    rs1 + zeroExtend(decodedInstruction.specific.LoadInstruction.offset));
                effectiveAddress = directAddress & ~'h3;
                case(directAddress & 'h3)
                    'b00: byteMask = 'b0001;
                    'b01: byteMask = 'b0010;
                    'b10: byteMask = 'b0100;
                    'b11: byteMask = 'b1000;
                endcase
            end
            LH, LHU: begin
                let directAddress = (operator == LH ? 
                    rs1 + signExtend(decodedInstruction.specific.LoadInstruction.offset) :
                    rs1 + zeroExtend(decodedInstruction.specific.LoadInstruction.offset));
                effectiveAddress = directAddress & ~'h3;
                case(directAddress & 'h3)
                    'b00: byteMask = 'b0011;
                    'b01: misaligned = True;
                    'b10: byteMask = 'b1100;
                    'b11: misaligned = True;
                endcase
            end
            LW: begin
                let directAddress = rs1 + signExtend(decodedInstruction.specific.LoadInstruction.offset);
                effectiveAddress = directAddress & ~'h3;
                if ((directAddress & 'h3) != 0) begin
                    misaligned = True;
                end else begin
                    byteMask = 'b1111;
                end
            end
        endcase

        let alignedData = rs2 << {effectiveAddress[1:0], 3'b0}; 
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: currentPc + 4,
            writeBack: decodedInstruction.specific.LUIInstruction.rd,
            writeBackData: 0,       // Will be set when the memory request returns.
            byteMask: byteMask,
            effectiveAddress: effectiveAddress,
            alignedData: alignedData,
            misaligned: misaligned
        };
    endfunction

    //
    // LUI
    //
    function ExecutedInstruction executeLUIInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
        let data = 0;
        data[31:12] = decodedInstruction.specific.LUIInstruction.immediate;
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: currentPc + 4,
            writeBack: decodedInstruction.specific.LUIInstruction.rd,
            writeBackData: data,
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // OP
    //
    function ExecutedInstruction executeOPInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: currentPc + 4,
            writeBack: decodedInstruction.specific.ALUInstruction.rd,
            writeBackData: alu.execute(rs1, rs2, decodedInstruction.specific.ALUInstruction.operator),
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // OPIMM
    //
    function ExecutedInstruction executeOPIMMInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: currentPc + 4,
            writeBack: decodedInstruction.specific.ALUInstruction.rd,
            writeBackData: alu.execute_immediate(rs1, decodedInstruction.specific.ALUInstruction.immediate, decodedInstruction.specific.ALUInstruction.operator),
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // SYSTEM
    //
    function ExecutedInstruction executeSYSTEMInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: currentPc + 4,
            writeBack: 0,           // Unused
            writeBackData: 0,       // Unused
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    //
    // UNSUPPORTED
    //
    function ExecutedInstruction executeUNSUPPORTEDInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            nextPc: 0,              // Unused
            writeBack: 0,           // Unused
            writeBackData: 0,       // Unused
            byteMask: 0,            // Unused
            effectiveAddress: 0,    // Unused
            alignedData: 0,         // Unused
            misaligned: False       // Unused
        };
    endfunction

    function ExecutedInstruction executeDecodedInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
        return case(decodedInstruction.instructionType)
            AUIPC:  return executeAUIPCInstruction(decodedInstruction, currentPc);
            BRANCH: return executeBRANCHInstruction(decodedInstruction, currentPc, rs1, rs2);
            JAL:    return executeJALInstruction(decodedInstruction, currentPc);
            JALR:   return executeJALRInstruction(decodedInstruction, currentPc, rs1);
            OP:     return executeOPInstruction(decodedInstruction, currentPc, rs1, rs2);
            OPIMM:  return executeOPIMMInstruction(decodedInstruction, currentPc, rs1);
            LUI:    return executeLUIInstruction(decodedInstruction, currentPc);
            LOAD:   return executeLOADInstruction(decodedInstruction, currentPc, rs1, rs2);
            // STORE: Nothing to do
            SYSTEM: return executeSYSTEMInstruction(decodedInstruction, currentPc);
            UNSUPPORTED: return executeUNSUPPORTEDInstruction(decodedInstruction, currentPc);
        endcase;
    endfunction

    rule execute;
        let decodedInstruction = decodedInstructionQueue.first();
        decodedInstructionQueue.deq();

        Word rs1 = registerFile.read1(decodedInstruction.rs1);
        Word rs2 = registerFile.read1(decodedInstruction.rs2);

        let executedInstruction = executeDecodedInstruction(decodedInstruction, programCounter, rs1, rs2);
        outputQueue.enq(executedInstruction);
    endrule

    method Action enableTracing;
        trace <= True;
    endmethod
endmodule
