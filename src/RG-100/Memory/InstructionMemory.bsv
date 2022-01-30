import RGTypes::*;

typedef struct {
    Word address;
} InstructionMemoryRequest deriving(Bits, Eq, FShow);

typedef struct {
    Word address;
    Word data;
} InstructionMemoryResponse deriving(Bits, Eq, FShow);

interface InstructionMemory;
    method Action request(InstructionMemoryRequest request);
    method InstructionMemoryResponse first();
    method Action deq();
    method Bool canDeq();
endinterface
