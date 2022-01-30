import RGTypes::*;

interface DataMemory;
    method Action request(Word address, Word value, Bit#(4) writeEnable);
    method Word first;
    method Action deq;
endinterface
