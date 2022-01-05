import FIFOF::*;
import Instruction::*;
import MemUtil::*;
import Port::*;
import RVTypes::*;

// ================================================================
// Exports
export InstructionFetcher (..), mkInstructionFetcher;

interface InstructionFetcher;
endinterface

module mkInstructionFetcher#(
    Reg#(Word) programCounter,
    ReadOnlyMemServerPort#(32, 2) instructionFetch,
    FIFOF#(Tuple2#(ProgramCounter, Word32)) outputQueue
)(InstructionFetcher);
    Reg#(Word) lastFetchedProgramCounter <- mkReg('hFFFF);

    rule requestMemory (programCounter != lastFetchedProgramCounter);
        // Perform memory request
        instructionFetch.request.enq(ReadOnlyMemReq{ addr: programCounter });
    endrule

    rule enqueueMemory;
        // Get memory response
        let instructionResponse = instructionFetch.response.first();
        instructionFetch.response.deq();

        outputQueue.enq(tuple2(programCounter, instructionResponse.data));
    endrule
endmodule
