import FIFO::*;
import Cache::*;
import CacheArrayUnit::*;
import Memory::*;

// module mkDirectMappedCache(Cache#(indexBitCount));
//     CacheArrayUnit#(indexBitCount)  cacheArrayUnit <- mkCacheArrayUnit();

//     // Cache server
//     FIFO#(MemoryRequest#(32, 32))   cacheServerRequests <- mkFIFO();
//     FIFO#(MemoryResponse#(32))  cacheServerResponses <- mkFIFO();

//     // Main memory client
//     FIFO#(MemoryRequest#(512, 512))  mainMemoryClientRequests <- mkFIFO();
//     FIFO#(MemoryResponse#(512)) mainMemoryClientResponses <- mkFIFO();

// endmodule
