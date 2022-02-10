import RGTypes::*;
import MemorySystem::*;
import BRAMServerTile::*;

import Assert::*;

typedef enum {
    INSTRUCTION_MEMORY_TEST_SETUP,
    INSTRUCTION_MEMORY_TEST,
    DATA_MEMORY_READ_TEST_SETUP,
    DATA_MEMORY_READ_TEST,
    COMPLETE
} TestPhase deriving(Bits, Eq);

(* synthesize *)
module mkMemorySystem_test(Empty);
    // BRAM Server Tile
    DualPortBRAMServerTile memory <- mkBRAMServerTileFromFile(32, "MemorySystem_test.hex");

    // Memory System
    MemorySystem memorySystem <- mkMemorySystem(memory);

    Reg#(TestPhase) testPhase <- mkReg(INSTRUCTION_MEMORY_TEST_SETUP);
    Reg#(Word) addressToCheck <- mkReg(0);
    Reg#(Word) cycleCounter <- mkReg(0);
    Reg#(Word) startCycle <- mkReg(0);
    Reg#(Bool) waitingForResponse <- mkReg(False);

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
    endrule

    rule instructionMemoryTestSetup(testPhase == INSTRUCTION_MEMORY_TEST_SETUP);
        testPhase <= INSTRUCTION_MEMORY_TEST;
    endrule

    (* fire_when_enabled *)
    rule instructionMemoryRequest(testPhase == INSTRUCTION_MEMORY_TEST && waitingForResponse == False);
        $display("[Instruction Memory] Requesting value from $%x", addressToCheck);
        memorySystem.instructionMemory.request.put(InstructionMemoryRequest {
            a_opcode: pack(A_GET),
            a_param: 0,
            a_size: 1,
            a_source: 0,
            a_address: addressToCheck,
            a_mask: 4'b1111,
            a_data: ?,
            a_corrupt: False
        });
        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

    (* fire_when_enabled *) //descending_urgency="incrementCycleCounter, request, check" *)
    rule instructionMemoryCheck(testPhase == INSTRUCTION_MEMORY_TEST && waitingForResponse == True);
        let response <- memorySystem.instructionMemory.response.get;
        dynamicAssert(response.d_opcode == pack(D_ACCESS_ACK_DATA), "[Instruction Memory] FAILED: Incorrect d_opcode");
        dynamicAssert(response.d_param == 0, "[Instruction Memory] FAILED: Incorrect d_param");
        dynamicAssert(response.d_size == 1, "[Instruction Memory] FAILED: Incorrect d_size");
        dynamicAssert(response.d_source == 0, "[Instruction Memory] FAILED: Incorrect d_source");
        dynamicAssert(response.d_sink == 0, "[Instruction Memory] FAILED: Incorrect d_sink");
        dynamicAssert(response.d_denied == False, "[Instruction Memory] FAILED: Incorrect d_denied");
        dynamicAssert(response.d_data == truncate(addressToCheck), "[Instruction Memory] FAILED: Incorrect d_data");
        dynamicAssert(response.d_corrupt == False, "[Instruction Memory] FAILED: Incorrect d_corrupt");

        Word expectedLatency = 3;
        let requestLatency = cycleCounter - startCycle;
        if (requestLatency != expectedLatency) begin
            $display("[Instruction Memory] FAILED: Request latency ($%x) != expected latency ($%x)", requestLatency, expectedLatency);
            $fatal();
        end

        if (addressToCheck == 'h10) begin
            testPhase <= DATA_MEMORY_READ_TEST_SETUP;
        end

        addressToCheck <= addressToCheck + 4;
        waitingForResponse <= False;
    endrule

    (* fire_when_enabled *)
    rule dataMemoryTestSetup(testPhase == DATA_MEMORY_READ_TEST_SETUP);
        testPhase <= DATA_MEMORY_READ_TEST;
        addressToCheck <= 0;
        waitingForResponse <= False;
    endrule

    (* fire_when_enabled *)
    rule dataMemoryReadRequest(testPhase == DATA_MEMORY_READ_TEST && waitingForResponse == False);
        $display("[Data Memory] Requesting value from $%x", addressToCheck);
        memorySystem.dataMemory.request.put(DataMemoryRequest {
            a_opcode: pack(A_GET),
            a_param: 0,
            a_size: 1,
            a_source: 0,
            a_address: addressToCheck,
            a_mask: 4'b1111,
            a_data: ?,
            a_corrupt: False
        });

        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

    rule dataMemoryCheck(testPhase == DATA_MEMORY_READ_TEST && waitingForResponse == True);
        let response <- memorySystem.dataMemory.response.get;
        dynamicAssert(response.d_opcode == pack(D_ACCESS_ACK_DATA), "[Data Memory] FAILED: Incorrect d_opcode");
        dynamicAssert(response.d_param == 0, "[Data Memory] FAILED: Incorrect d_param");
        dynamicAssert(response.d_size == 1, "[Data Memory] FAILED: Incorrect d_size");
        dynamicAssert(response.d_source == 0, "[Data Memory] FAILED: Incorrect d_source");
        dynamicAssert(response.d_sink == 0, "[Data Memory] FAILED: Incorrect d_sink");
        dynamicAssert(response.d_denied == False, "[Data Memory] FAILED: Incorrect d_denied");
        dynamicAssert(response.d_data == truncate(addressToCheck), "[Data Memory] FAILED: Incorrect d_data");
        dynamicAssert(response.d_corrupt == False, "[Data Memory] FAILED: Incorrect d_corrupt");

        Word expectedLatency = 3;
        let requestLatency = cycleCounter - startCycle;
        if (requestLatency != expectedLatency) begin
            $display("[Data Memory] FAILED: Request latency ($%x) != expected latency ($%x)", requestLatency, expectedLatency);
            $fatal();
        end

        if (extend(response.d_data) != addressToCheck) begin
            $display("[Data Memory] FAILED: Request data ($%x) != address to check ($%x)", response.d_data, addressToCheck);
            $fatal();
        end

        if (addressToCheck == 'h10) begin
            testPhase <= COMPLETE;
        end

        addressToCheck <= addressToCheck + fromInteger(valueOf(TDiv#(XLEN, 8)));
        waitingForResponse <= False;
    endrule

    rule complete(testPhase == COMPLETE);
        $display("--- PASS");
        $finish();
    endrule
endmodule
