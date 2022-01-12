import RVTypes::*;

interface InstructionMemory;
    method Action request(Word address);
    method Word first();
    method Action deq();
    method Bool canDeq();
endinterface
