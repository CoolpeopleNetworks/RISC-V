import Common::*;

typedef enum { 
    Ld, 
    St 
} MemoryOperation deriving(Bits, Eq);

typedef struct { 
    MemoryOperation operation;
    Word address;
    Word data;
} MemoryRequest deriving(Bits, Eq);

interface MemoryController;
    method Action request(MemoryRequest memoryRequest);
    method ActionValue#(Word) response();
endinterface

(* synthesize *)
module mkMemoryController(MemoryController);
    method Action request(MemoryRequest memoryRequest);
    endmethod

    method ActionValue#(Word) response();
        return 0;
    endmethod
endmodule
