import RGTypes::*;

import EncodedInstruction::*;
import InstructionMemory::*;
import PipelineController::*;
import ProgramCounterRedirect::*;

import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export mkFetchUnit, FetchUnit(..);

typedef struct {
    PipelineEpoch epoch;
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
    InstructionMemory instructionMemory,
    Reg#(Bool) fetchEnabled
)(FetchUnit);
    Reg#(Word) fetchCounter <- mkReg(0);
    Reg#(ProgramCounter) programCounter[2] <- mkCReg(2, initialProgramCounter);
    FIFO#(EncodedInstruction) outputQueue <- mkPipelineFIFO();
    Reg#(PipelineEpoch) currentEpoch <- mkReg(0);

    FIFO#(FetchInfo) fetchInfoQueue <- mkPipelineFIFO(); // holds the fetch info for the current instruction request

    function ProgramCounter getEffectiveAddress(Word base, Word signedOffset);
        Int#(XLEN) offset = unpack(signedOffset);
        return pack(unpack(base) + offset);
    endfunction

    function ProgramCounter predictNextProgramCounter(InstructionMemoryResponse imr);
`ifdef DISABLE_BRANCH_PREDICTION
        return imr.address + 4;
`else
        let instruction = imr.data;
        let opcode = instruction[6:0];
        let predictedProgramCounter = imr.address + 4;

        case(opcode)
            7'b1100011: begin // BRANCH
                // If the offset is negative (upper bit set), predict branch taken
                if (instruction[31] == 1) begin
                    Word immediate = signExtend({
                        instruction[31],        // 1 bit
                        instruction[7],         // 1 bit
                        instruction[30:25],     // 6 bits
                        instruction[11:8],      // 4 bits
                        1'b0                    // 1 bit
                    });

                    predictedProgramCounter = getEffectiveAddress(imr.address, immediate);
                end 
            end
        endcase
        return predictedProgramCounter;
`endif
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

        instructionMemory.request(InstructionMemoryRequest {
            address: fetchProgramCounter
        });

        fetchInfoQueue.enq(FetchInfo {
            epoch: fetchEpoch,
            index: fetchCounter
        });

        fetchCounter <= fetchCounter + 1;
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse;
        let fetchResponse = instructionMemory.first();
        instructionMemory.deq();

        let fetchInfo = fetchInfoQueue.first();
        fetchInfoQueue.deq();

        $display("%0d,%0d,%0d,%0d,%0d,fetch receive,encoded instruction=%08h", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchResponse.address, stageNumber, fetchResponse.data);

        // Predict what the next program counter will be
        let predictedNextProgramCounter = predictNextProgramCounter(fetchResponse);
        $display("%0d,%0d,%0d,%0d,%0d,fetch receive,predicted next instruction=$%8x", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchResponse.address, stageNumber, predictedNextProgramCounter);
        programCounter[0] <= predictedNextProgramCounter;

        // Tell the decode stage what the program counter for the insruction it'll receive.
        outputQueue.enq(EncodedInstruction {
            fetchIndex: fetchInfo.index,
            programCounter: fetchResponse.address,
            predictedNextProgramCounter: predictedNextProgramCounter,
            pipelineEpoch: fetchInfo.epoch,
            rawInstruction: fetchResponse.data
        });
    endrule

    interface FIFO getEncodedInstructionQueue = outputQueue;

endmodule
