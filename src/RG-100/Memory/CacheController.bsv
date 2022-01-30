import RGTypes::*;
import Vector::*;
import BRAM::*;

interface CacheController;
    method Action request(Word address);
    method Word first;
    method Action deq;
endinterface

// typedef struct {
//     Vector#(TExp#(logLine), Bit#(8)) data;
// } CacheLine#(type logLineSize) deriving(Bits, Eq);

module mkCacheController#(
    Integer logLineSize,
    Integer logLineCount
)(CacheController);

    // BRAM_Configure bramConfig = default;
    // BRAM1PortBE#(Word, CacheLine#(logLineSize)) cacheData = mkBRAM1ServerBE(bramConfig);

    Integer tagBitCount = valueof(XLEN)-logLineSize-logLineCount;

    function Bit#(logLineSize) lineOffset(Word address);
        return address[logLineSize - 1:0];
    endfunction

    function Bit#(logLineCount) lineIndex(Word address);
        return address[logLineCount - 1:logLineSize];
    endfunction

    function Bit#(tagBitCount) lineTag(Word address);
        return address[valueof(XLEN)-1:logLineSize+logLineCount];
    endfunction

    method Action request(Word address);

    endmethod

    method Word first;
        return 0;
    endmethod

    method Action deq;
    endmethod

endmodule
