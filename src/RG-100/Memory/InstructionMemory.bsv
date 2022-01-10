import RVTypes::*;

interface InstructionMemory;
    method Action request(Word address);
    method Word first();
    method Action deq();
endinterface
