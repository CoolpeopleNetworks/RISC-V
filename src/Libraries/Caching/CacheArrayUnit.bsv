import Memory::*;

typedef struct {

} Line deriving(Bits, Eq);

typedef struct {

} CacheTag deriving(Bits, Eq);

typedef UInt#(indexBitCount) CacheIndex#(numeric type indexBitCount);

typedef enum {
    Invalid,    // Line is unused.
    Clean,      // Line unchanged with respect to main memory.
    Dirty       // Line needs to be written back to main memory.
} LineStatus deriving(Bits, Eq);

typedef struct {
    Line line;
    LineStatus status;
    CacheTag tag;
} TaggedLine deriving(Bits, Eq);

typedef enum {
    LoadHit,
    StoreHit,
    Miss
} HitMissType deriving(Bits, Eq);

typedef struct {
    HitMissType hitMissType;
    union tagged {
        MemoryResponse#(32) LoadData;   // LoadHit
        TaggedLine TaggedLine;          // Miss
    } specific;
} CacheResponse deriving(Bits, Eq);

interface CacheArrayUnit#(numeric type indexBitCount);
    method Action request(MemoryRequest#(32, 32) request);
    method ActionValue#(CacheResponse) response();
    method Action update(CacheIndex#(indexBitCount) index, TaggedLine newLine);     // Write data to cache (store)
endinterface

// module mkCacheArrayUnit(CacheArrayUnit#(indexBitCount));
//     method Action request(MemoryRequest#(32, 32) request);
//     endmethod

//     method ActionValue#(CacheResponse) response();
//     endmethod

//     method Action update(CacheIndex#(indexBitCount) index, TaggedLine newLine);
//     endmethod
// endmodule
