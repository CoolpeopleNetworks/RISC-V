import RegFile::*;
import RVTypes::*;
import MemUtil::*;
import RG100Core::*;

(* synthesize *)
module mkCoreTest(Empty);
    // Instruction Memory
    RegFile#(Word, Word) instructionRegisterFile <- mkRegFileFullLoad("CoreTests.txt");
    ReadOnlyMemServerPort#(32, 2) instructionMemory <- mkMemServerPortFromRegFile(instructionRegisterFile);

    // Data Memory
    AtomicBRAM#(32, TLog#(TDiv#(32,8)), 1024) dataMemory <- mkAtomicBRAM();

    // Core
    RG100Core core <- mkCore(instructionMemory, dataMemory.portA);
endmodule
