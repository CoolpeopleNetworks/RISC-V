import RegFile::*;
import RVTypes::*;
import MemUtil::*;
import RG100Core::*;

(* synthesize *)
module mkCoreTest(Empty);
    // Instruction Memory
    RegFile#(Word, Word) instructionRegisterFile <- mkRegFileFullLoad("./src/RG-100/Core/tests/CoreTest.txt");
    ReadOnlyMemServerPort#(32, 2) instructionMemory <- mkMemServerPortFromRegFile(instructionRegisterFile);

    // Data Memory
    AtomicBRAM#(32, TLog#(TDiv#(32,8)), 1024) dataMemory <- mkAtomicBRAM();

    // Core
    RG100Core core <- mkCore(0, instructionMemory, dataMemory.portA);
endmodule
