import RGTypes::*;
import MemorySystem::*;

typedef enum {
    INSTRUCTION_MEMORY_TEST_SETUP,
    INSTRUCTION_MEMORY_TEST,
    DATA_MEMORY_READ_TEST_SETUP,
    DATA_MEMORY_READ_TEST,
    COMPLETE
} TestPhase deriving(Bits, Eq);

(* synthesize *)
module mkMemorySystem_test(Empty);
    MemorySystem memorySystem <- mkMemorySystemFromFile(4, "MemorySystem_test.hex");

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
            address: addressToCheck
        });
        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

    (* fire_when_enabled *) //descending_urgency="incrementCycleCounter, request, check" *)
    rule instructionMemoryCheck(testPhase == INSTRUCTION_MEMORY_TEST && waitingForResponse == True);
        let response <- memorySystem.instructionMemory.response.get;
        if (response.address != addressToCheck) begin
            $display("[Instruction Memory] FAILED: Request address ($%x) != address to check ($%x)", response.address, addressToCheck);
            $fatal();
        end

        if (response.data != truncate(addressToCheck)) begin
            $display("[Instruction Memory] FAILED: Request data ($%x) != address to check ($%x)", response.data, addressToCheck);
            $fatal();
        end

        Word expectedLatency = 1;
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
        memorySystem.dataMemory.request.put(MemoryRequest {
            write: False,
            byteen: 0,
            address: addressToCheck,
            data: ?
        });
        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

    rule dataMemoryCheck(testPhase == DATA_MEMORY_READ_TEST && waitingForResponse == True);
        let response <- memorySystem.dataMemory.response.get;
        if (response.data != addressToCheck) begin
            $display("[Data Memory] FAILED: Request data ($%x) != address to check ($%x)", response.data, addressToCheck);
            $fatal();
        end

        Word expectedLatency = 1;
        let requestLatency = cycleCounter - startCycle;
        if (requestLatency != expectedLatency) begin
            $display("[Data Memory] FAILED: Request latency ($%x) != expected latency ($%x)", requestLatency, expectedLatency);
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
