import RVTypes::*;
import InstructionMemory::*;
import ProgramCounterRedirect::*;

import GetPut::*;
import FIFO::*;
import SpecialFIFOs::*;
import EncodedInstruction::*;

export mkFetchUnit, FetchUnit(..);

interface FetchUnit;
    interface Get#(EncodedInstruction) getEncodedInstruction;
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

    FIFO#(PipelineEpoch) instructionEpoch <- mkFIFO(); // holds the epoch for the current instruction request

`ifdef PIPELINED
    (* fire_when_enabled *) this can't be enabled in non-pipelined mode.
`endif
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

            $display("%0d,%0d,%0d,%0d,fetch,redirected PC: $%08x", cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);
        end

        $display("%0d,%0d,%0d,%0d,fetch,fetching instruction", cycleCounter, fetchEpoch, programCounter, stageNumber);

        instructionMemory.request(InstructionMemoryRequest {
            address: fetchProgramCounter
        });
        instructionEpoch.enq(fetchEpoch);

        programCounter <= fetchProgramCounter + 4;

`ifndef PIPELINED
        fetchEnabled <= False;
`endif
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse;
        let fetchResponse = instructionMemory.first();
        instructionMemory.deq();

        let fetchEpoch = instructionEpoch.first();
        instructionEpoch.deq();

        // Tell the decode stage what the program counter for the insruction it'll receive.
        outputQueue.enq(EncodedInstruction {
            programCounter: fetchResponse.address,
            pipelineEpoch: fetchEpoch,
            rawInstruction: fetchResponse.data
        });
    endrule

    interface Get getEncodedInstruction = fifoToGet(outputQueue);

endmodule
