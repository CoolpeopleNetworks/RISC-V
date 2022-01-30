import RegFile::*;
import RGTypes::*;
import MemUtil::*;
import RG100Core::*;

import InstructionMemory::*;
import DataMemory::*;

import Port::*;
import MemUtil::*;
import FIFO::*;

(* synthesize *)
module mkInstructionMemory(InstructionMemory);
    RegFile#(Word, Word) instructionRegisterFile <- mkRegFileFullLoad("./src/RG-100/Core/tests/CoreTest.txt");
    ReadOnlyMemServerPort#(32, 2) memory <- mkMemServerPortFromRegFile(instructionRegisterFile);

    FIFO#(Word) requestAddress <- mkFIFO();

    method Action request(InstructionMemoryRequest r);
        memory.request.enq(ReadOnlyMemReq{ addr: r.address });
        requestAddress.enq(r.address);
    endmethod

    method InstructionMemoryResponse first;
        return InstructionMemoryResponse {
            address: requestAddress.first(),
            data: memory.response.first().data()
        };
    endmethod

    method Action deq;
        requestAddress.deq();
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
    RG100Core core <- mkRG100Core(0, instructionMemory, dataMemory);
endmodule
