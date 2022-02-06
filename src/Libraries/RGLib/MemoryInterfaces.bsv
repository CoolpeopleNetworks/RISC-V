import RGTypes::*;

import BRAM::*;
import ClientServer::*;
import GetPut::*;
import Memory::*;

export BRAM::*, ClientServer::*, GetPut::*, Memory::*, 
       InstructionMemoryRequest(..), InstructionMemoryResponse(..),
       InstructionMemoryClient, InstructionMemoryServer,
       DataMemoryClient, DataMemoryServer;

typedef struct {
    Word address;
} InstructionMemoryRequest deriving(Bits, Eq, FShow);

typedef struct {
    Word address;
    Word32 data;
} InstructionMemoryResponse deriving(Bits, Eq, FShow);

typedef Client#(InstructionMemoryRequest, InstructionMemoryResponse) InstructionMemoryClient;
typedef Server#(InstructionMemoryRequest, InstructionMemoryResponse) InstructionMemoryServer;

typedef Client#(MemoryRequest#(XLEN, XLEN), MemoryResponse#(XLEN)) DataMemoryClient;
typedef Server#(MemoryRequest#(XLEN, XLEN), MemoryResponse#(XLEN)) DataMemoryServer;
