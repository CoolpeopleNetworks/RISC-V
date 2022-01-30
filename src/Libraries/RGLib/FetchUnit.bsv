import RGTypes::*;

import EncodedInstruction::*;
import InstructionMemory::*;
import PipelineController::*;
import ProgramCounterRedirect::*;

import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export mkFetchUnit, FetchUnit(..);

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
    Reg#(ProgramCounter) programCounter <- mkReg(initialProgramCounter);
    FIFO#(EncodedInstruction) outputQueue <- mkPipelineFIFO();
    Reg#(PipelineEpoch) currentEpoch <- mkReg(0);

    FIFO#(PipelineEpoch) instructionEpoch <- mkPipelineFIFO(); // holds the epoch for the current instruction request

    (* fire_when_enabled *)
    rule sendFetchRequest(fetchEnabled == True);
        // Get the current program counter from the 'fetchProgramCounter' register, if the 
        // program counter redirect has a value, move that into the program counter and
        // increment the epoch.
        let fetchProgramCounter = programCounter;
        let fetchEpoch = currentEpoch;
        let redirectedProgramCounter <- programCounterRedirect.getRedirectedProgramCounter();
        if (isValid(redirectedProgramCounter)) begin
            fetchProgramCounter = fromMaybe(?, redirectedProgramCounter);

            fetchEpoch = fetchEpoch + 1;
            currentEpoch <= fetchEpoch;

            $display("%0d,%0d,%0d,%0d,fetch send,redirected PC: $%08x", cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);
        end

        $display("%0d,%0d,%0d,%0d,fetch send,fetch address: $%08x", cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);

        instructionMemory.request(InstructionMemoryRequest {
            address: fetchProgramCounter
        });
        instructionEpoch.enq(fetchEpoch);

        programCounter <= fetchProgramCounter + 4;
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse;
        let fetchResponse = instructionMemory.first();
        instructionMemory.deq();

        let fetchEpoch = instructionEpoch.first();
        instructionEpoch.deq();

        $display("%0d,%0d,%0d,%0d,fetch receive,encoded instruction=%08h", cycleCounter, fetchEpoch, fetchResponse.address, stageNumber, fetchResponse.data);

        // Tell the decode stage what the program counter for the insruction it'll receive.
        outputQueue.enq(EncodedInstruction {
            programCounter: fetchResponse.address,
            pipelineEpoch: fetchEpoch,
            rawInstruction: fetchResponse.data
        });
    endrule

    interface FIFO getEncodedInstructionQueue = outputQueue;

endmodule
