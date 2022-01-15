import RVTypes::*;

import DataMemory::*;

export 

module mkSimulatedDDR#(type latency)(DataMemory);
    Reg#(Word) latency = mkRegU();

    rule latencyTicker;

    endrule
endmodule