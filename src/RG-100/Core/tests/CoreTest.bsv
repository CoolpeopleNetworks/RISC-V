import RegFile::*;
import RVTypes::*;
import MemUtil::*;
import RG100Core::*;

import InstructionMemory::*;
import DataMemory::*;

import Port::*;
import MemUtil::*;

import CacheController::*;

(* synthesize *)
module mkInstructionMemory(InstructionMemory);
    RegFile#(Word, Word) instructionRegisterFile <- mkRegFileFullLoad("./src/RG-100/Core/tests/CoreTest.txt");
    ReadOnlyMemServerPort#(32, 2) memory <- mkMemServerPortFromRegFile(instructionRegisterFile);

    method Action request(Word address);
        memory.request.enq(ReadOnlyMemReq{ addr: address });
    endmethod

    method Word first;
        return memory.response.first().data();
    endmethod

    method Action deq;
        memory.response.deq();
    endmethod

    method Bool canDeq();
        return memory.response.canDeq();
    endmethod
endmodule

(* synthesize *)
module mkDataMemory(DataMemory);
    AtomicBRAM#(32, DataSz#(32), 1024) dataMemory <- mkAtomicBRAM();

    method Action request(Word address, Word value, Bit#(4) writeEnable);
        dataMemory.portA.request.enq(AtomicMemReq {
            write_en: writeEnable,
            atomic_op: None,
            addr: address,
            data: value
        });
    endmethod

    method Bool isLoadReady;
        return dataMemory.portA.response.canDeq();
    endmethod

    method Word first;
        return dataMemory.portA.response.first().data();
    endmethod

    method Action deq;
        dataMemory.portA.response.deq();
    endmethod

endmodule

(* synthesize *)
module mkCoreTest(Empty);
    // Instruction Memory
    InstructionMemory instructionMemory <- mkInstructionMemory();

    // Data Memory
    DataMemory dataMemory <- mkDataMemory();

    // Core
    RG100Core core <- mkRG100Core(0, instructionMemory, dataMemory, 200, True);
endmodule
