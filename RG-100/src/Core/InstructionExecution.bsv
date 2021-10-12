import ALU::*;
import Common::*;
import Instruction::*;
import LoadStore::*;

function DecodedInstruction executeDecodedInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
    return case(decodedInstruction.instructionType)
        JAL:    return executeJalInstruction(decodedInstruction, currentPc);
        OP:     return executeOpInstruction(decodedInstruction, currentPc, rs1, rs2);
        OPIMM:  return executeOpImmInstruction(decodedInstruction, currentPc, rs1);
        LOAD:   return executeLoadInstruction(decodedInstruction, currentPc, rs1);
    endcase;
endfunction

//
// JAL
//
function DecodedInstruction executeJalInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
    decodedInstruction.nextPc = currentPc + signExtend(decodedInstruction.operation.JALOperation.offset);
    return decodedInstruction;
endfunction

//
// OP
//
function DecodedInstruction executeOpInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1, Word rs2);
    let specific = decodedInstruction.specific.ALUInstruction;
    specific.result = ALU::execute(rs1, rs2, decodedInstruction.operation.ALUOperation.operator);
    decodedInstruction.specific = tagged ALUInstruction specific;
    decodedInstruction.nextPc = currentPc + 4;
    return decodedInstruction;
endfunction

//
// OPIMM
//
function DecodedInstruction executeOpImmInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1);
    let immediate = signExtend(decodedInstruction.operation.ALUOperation.immediate);
    let specific = decodedInstruction.specific.ALUInstruction;
    specific.result = ALU::executeImmediate(rs1, immediate, decodedInstruction.operation.ALUOperation.operator);
    decodedInstruction.specific = tagged ALUInstruction specific;
    decodedInstruction.nextPc = currentPc + 4;
    return decodedInstruction;
endfunction

//
// LOAD
//
function DecodedInstruction executeLoadInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word rs1);
    decodedInstruction.nextPc = currentPc + 4;
    return decodedInstruction;
endfunction
