import FIFOF::*;
import Instruction::*;
import MemUtil::*;
import Port::*;
import RVTypes::*;

// ================================================================
// Exports
export InstructionFetcher (..), mkInstructionFetcher, InstructionFetcherOutput;

typedef struct {
    FIFOF#(Word32) encodedInstructionQueue;
} InstructionFetcherOutput deriving(Bits);

interface InstructionFetcher;
    (* always_ready *)
    method InstructionFetcherOutput out;
endinterface

module mkInstructionFetcher#(
    Reg#(Word) programCounter,
    ReadOnlyMemServerPort#(32, 2) instructionFetch,
    FIFOF#(Tuple2#(ProgramCounter, Word32)) outputQueue
)(InstructionFetcher);
    Reg#(Word) lastFetchedProgramCounter <- mkReg(0);

    rule fetch (programCounter != lastFetchedProgramCounter);
        instructionFetch.request.enq(ReadOnlyMemReq{ addr: programCounter });
        let instructionResponse = instructionFetch.response.first();
        instructionFetch.response.deq();

        outputQueue.enq(tuple2(programCounter, instructionResponse.data));
    endrule

    method InstructionFetcherOutput out;
        InstructionFetcherOutput _output = ?;

        return _output;
    endmethod

endmodule
