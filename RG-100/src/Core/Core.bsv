import ALU::*;
import Common::*;
import Instruction::*;
import InstructionDecoder::*;
import MemoryController::*;
import RegisterFile::*;
import TileLink::*;

import GetPut::*;
import ClientServer::*;
import FIFOF::*;

interface Core;
    interface TileLinkADClient32 instructionBusClient;
//    interface CoreToCacheClient dataBusClient;
endinterface

// typedef enum {
//     Fetch,
//     Execute,
//     LoadWait
// } State deriving(Bits, Eq);

typedef struct {
    InstructionType instructionType;
    Maybe#(RegisterIndex) destinationRegister;
    Word destinationData;
    Word nextPc;
} ExecutedInstruction deriving(Bits, Eq);

(* synthesize *)
module mkCore(Core);
    Reg#(ProgramCounter)        pc <- mkReg(0);
    RegisterFile                registerFile <- mkRegisterFile();
//    ALU                         alu <- mkALU();

    MemoryController            memoryController <- mkMemoryController();

    //
    // Instruction FIFO
    //
    FIFO#(TileLinkChannelARequest32) instructionFIFORequests <- mkFIFO;
    FIFO#(TileLinkChannelDResponse32) instructionFIFOResponses <- mkFIFO;

    //
    // Decode
    //
    FIFOF#(DecodedInstruction)  decodeFifo <- mkFIFOF;       // decode output

    rule fetch(instructionFifo.notFull());
        //memoryController.request(MemoryRequest{operation: Ld, address: pc, data: ?});
    endrule

    rule decode(instructionFifo.notEmpty());
        let instruction = instructionFifo.first();
        instructionFifo.deq();

        decodeFifo.enq(InstructionDecoder::decode(instruction));
    endrule

    rule execute(decodeFifo.notEmpty());
        let decodedInstruction = decodeFifo.first();
        decodeFifo.deq();

        let r1 = registerFile.read1(decodedInstruction.sourceRegister1);
        let r2 = registerFile.read2(decodedInstruction.sourceRegister2);

        let executedInstruction = executeDecodedInstruction(decodedInstruction, pc, r1, r2);
        if (executedInstruction.instructionType == LOAD || executedInstruction.instructionType == STORE) begin
//            e2m <= executedInstruction;
//           state <= LoadWait;
        end else begin
            if (isValid(executedInstruction.destinationRegister)) begin
                registerFile.write(fromMaybe(?, executedInstruction.destinationRegister), executedInstruction.destinationData);
            end

            pc <= executedInstruction.nextPc;
//           state <= Fetch;
        end
    endrule

    // rule memoryAccess(state == LoadWait);
    //    updateState(e2m, pc, registers, memoryController);
    //    state <= Fetch;
    // endrule

    interface Client instructionBusClient;
        interface Put put;
            method Action put(a);
                instructionFifoRequests.enq(a);
            endmethod
        endinterface
        interface Get response;
            method ActionValue#(TileLinkChannelDResponse32) get;
                instructionFifoResponses.deq;
                return instructionFifoResponses.first;
            endmethod
        endinterface
    endinterface

    // interface CoreToCacheClient dataBusClient;
    // endinterface

endmodule

function ExecutedInstruction executeDecodedInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word r1, Word r2);
    return case(decodedInstruction.instructionType)
        JAL:    return executeJalInstruction(decodedInstruction, currentPc);
        OP:     return executeOpInstruction(decodedInstruction, currentPc, r1, r2);
        OPIMM:  return executeOpImmInstruction(decodedInstruction, currentPc, r1);
    endcase;
endfunction

function ExecutedInstruction executeJalInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc);
    let address = currentPc + signExtend(decodedInstruction.operation.JALOperation.offset);
    return ExecutedInstruction {
        instructionType: JAL,
        destinationRegister: tagged Valid decodedInstruction.operation.JALOperation.destinationRegister,
        destinationData: currentPc + 4,
        nextPc: address
    };
endfunction

function ExecutedInstruction executeOpInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word r1, Word r2);
    let result = ALU::execute(r1, r2, decodedInstruction.operation.ALUOperation.operator);
    return ExecutedInstruction {
        instructionType: OP,
        destinationRegister: tagged Valid decodedInstruction.operation.ALUOperation.destinationRegister,
        destinationData: result,
        nextPc: (currentPc + 4)
    };
endfunction

function ExecutedInstruction executeOpImmInstruction(DecodedInstruction decodedInstruction, ProgramCounter currentPc, Word r1);
    Word immediate = signExtend(decodedInstruction.operation.ALUOperation.immediate);
    let result = ALU::executeImmediate(r1, immediate, decodedInstruction.operation.ALUOperation.operator);
    return ExecutedInstruction {
        instructionType: OP,
        destinationRegister: tagged Valid decodedInstruction.operation.ALUOperation.destinationRegister,
        destinationData: result,
        nextPc: (currentPc + 4)
    };
endfunction
