//
// FetchUnit
//
// This module is a RISC-V instruction fetch unit.  It is responsible for fetching instructions 
// from memory and creating a EncodedInstruction structure representing them.
//
import RGTypes::*;

import BranchPredictor::*;
import EncodedInstruction::*;
import MemoryInterfaces::*;
import PipelineController::*;
import ProgramCounterRedirect::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export mkFetchUnit, FetchUnit(..);

typedef struct {
    PipelineEpoch epoch;
    Word address;
    Word index;     // The fetch index
} FetchInfo deriving(Bits, Eq, FShow);

interface FetchUnit;
    interface FIFO#(EncodedInstruction) getEncodedInstructionQueue;
endinterface

module mkFetchUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    ProgramCounter initialProgramCounter,
    ProgramCounterRedirect programCounterRedirect,
    InstructionMemoryServer instructionMemory,
    Reg#(Bool) fetchEnabled
)(FetchUnit);
    Reg#(Word) fetchCounter <- mkReg(0);
    Reg#(ProgramCounter) programCounter[2] <- mkCReg(2, initialProgramCounter);
    FIFO#(EncodedInstruction) outputQueue <- mkPipelineFIFO();
    Reg#(PipelineEpoch) currentEpoch <- mkReg(0);

    FIFO#(FetchInfo) fetchInfoQueue <- mkPipelineFIFO(); // holds the fetch info for the current instruction request

`ifdef DISABLE_BRANCH_PREDICTOR
    BranchPredictor branchPredictor <- mkNullBranchPredictor();
`else
    BranchPredictor branchPredictor <- mkBackwardBranchTakenPredictor();
`endif

    function ProgramCounter getEffectiveAddress(Word base, Word signedOffset);
        Int#(XLEN) offset = unpack(signedOffset);
        return pack(unpack(base) + offset);
    endfunction

    (* fire_when_enabled *)
    rule sendFetchRequest(fetchEnabled == True);
        // Get the current program counter from the 'fetchProgramCounter' register, if the 
        // program counter redirect has a value, move that into the program counter and
        // increment the epoch.
        let fetchProgramCounter = programCounter[1];
        let fetchEpoch = currentEpoch;
        let redirectedProgramCounter <- programCounterRedirect.getRedirectedProgramCounter();
        if (isValid(redirectedProgramCounter)) begin
            fetchProgramCounter = fromMaybe(?, redirectedProgramCounter);

            fetchEpoch = fetchEpoch + 1;
            currentEpoch <= fetchEpoch;

            $display("%0d,%0d,%0d,%0d,%0d,fetch send,redirected PC: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);
        end

        $display("%0d,%0d,%0d,%0d,%0d,fetch send,fetch address: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);

        instructionMemory.request.put(InstructionMemoryRequest {
            address: fetchProgramCounter
        });

        fetchInfoQueue.enq(FetchInfo {
            epoch: fetchEpoch,
            address: fetchProgramCounter,
            index: fetchCounter
        });

        fetchCounter <= fetchCounter + 1;
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse;
        let fetchResponse <- instructionMemory.response.get;

        let fetchInfo = fetchInfoQueue.first();
        fetchInfoQueue.deq();

        $display("%0d,%0d,%0d,%0d,%0d,fetch receive,encoded instruction=%08h", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, fetchResponse.data);

        // Predict what the next program counter will be
        let predictedNextProgramCounter = branchPredictor.predictNextProgramCounter(fetchInfo.address, fetchResponse.data);
        $display("%0d,%0d,%0d,%0d,%0d,fetch receive,predicted next instruction=$%x", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, predictedNextProgramCounter);
        programCounter[0] <= predictedNextProgramCounter;

        // Tell the decode stage what the program counter for the insruction it'll receive.
        outputQueue.enq(EncodedInstruction {
            fetchIndex: fetchInfo.index,
            programCounter: fetchInfo.address,
            predictedNextProgramCounter: predictedNextProgramCounter,
            pipelineEpoch: fetchInfo.epoch,
            rawInstruction: fetchResponse.data
        });
    endrule

    interface FIFO getEncodedInstructionQueue = outputQueue;

endmodule
