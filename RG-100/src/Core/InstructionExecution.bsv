import ALU::*;
import Common::*;
import Instruction::*;
import LoadStore::*;

function ExecutedInstruction executeDecodedInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
    return case(decodedInstruction.instructionType)
        AUIPC:  return executeAUIPCInstruction(decodedInstruction, currentPc);
        BRANCH: return executeBRANCHInstruction(decodedInstruction, currentPc, rs1, rs2);
        JAL:    return executeJALInstruction(decodedInstruction, currentPc);
        JALR:   return executeJALRInstruction(decodedInstruction, currentPc, rs1);
        OP:     return executeOPInstruction(decodedInstruction, currentPc, rs1, rs2);
        OPIMM:  return executeOPIMMInstruction(decodedInstruction, currentPc, rs1);
        LUI:    return executeLUIInstruction(decodedInstruction, currentPc);
        // LOAD: Nothing to do
        // STORE: Nothing to do
        UNSUPPORTED: return executeUNSUPPORTEDInstruction(decodedInstruction, currentPc);
    endcase;
endfunction

//
// AUIPC
//
function ExecutedInstruction executeAUIPCInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
    return ExecutedInstruction {
        decodedInstruction: decodedInstruction,
        nextPc: currentPc + 4,
        writeBack: decodedInstruction.specific.AUIPCInstruction.destination,
        writeBackData: currentPc + decodedInstruction.specific.AUIPCInstruction.offset
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
        writeBack: 0,       // Unused
        writeBackData: 0    // Unused
    };
endfunction

//
// JAL
//
function ExecutedInstruction executeJALInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
    return ExecutedInstruction {
        decodedInstruction: decodedInstruction,
        nextPc: currentPc + signExtend(decodedInstruction.specific.JALInstruction.offset),
        writeBack: decodedInstruction.specific.JALInstruction.destination,
        writeBackData: currentPc + 4
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
        writeBack: decodedInstruction.specific.JALRInstruction.destination,
        writeBackData: currentPc + 4
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
        writeBack: decodedInstruction.specific.LUIInstruction.destination,
        writeBackData: data
    };
endfunction

//
// OP
//
function ExecutedInstruction executeOPInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
    return ExecutedInstruction {
        decodedInstruction: decodedInstruction,
        nextPc: currentPc + 4,
        writeBack: decodedInstruction.specific.ALUInstruction.destination,
        writeBackData: ALU::execute(rs1, rs2, decodedInstruction.specific.ALUInstruction.operator)
    };
endfunction

//
// OPIMM
//
function ExecutedInstruction executeOPIMMInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1);
    let immediate = signExtend(decodedInstruction.specific.ALUInstruction.immediate);
    return ExecutedInstruction {
        decodedInstruction: decodedInstruction,
        nextPc: currentPc + 4,
        writeBack: decodedInstruction.specific.ALUInstruction.destination,
        writeBackData: ALU::execute(rs1, immediate, decodedInstruction.specific.ALUInstruction.operator)
    };
endfunction

//
// UNSUPPORTED
//
function ExecutedInstruction executeUNSUPPORTEDInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
    return ExecutedInstruction {
        decodedInstruction: decodedInstruction,
        nextPc: 0,
        writeBack: 0,
        writeBackData: 0
    };
endfunction
