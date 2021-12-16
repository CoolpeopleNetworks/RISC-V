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
    FIFOF#(Word32) outputQueue
)(InstructionFetcher);

    rule fetch;
        instructionFetch.request.enq(ReadOnlyMemReq{ addr: programCounter });
        let encodedInstruction = instructionFetch.response.first();
        instructionFetch.response.deq();

        outputQueue.enq(encodedInstruction.data);
    endrule

    method InstructionFetcherOutput out;
        InstructionFetcherOutput _output = ?;

        return _output;
    endmethod

endmodule
