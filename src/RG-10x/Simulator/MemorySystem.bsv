import RGTypes::*;
import TileLink::*;
import MemoryInterfaces::*;
import BRAMServerTile::*;

import ClientServer::*;
import GetPut::*;

export MemorySystem(..), 
       mkMemorySystem, 
       MemoryInterfaces::*,
       TileLink::*,
       ClientServer::*,
       GetPut::*;

interface MemorySystem;
    interface InstructionMemoryServer instructionMemory;
    interface DataMemoryServer dataMemory;
endinterface

module mkMemorySystem#(
    DualPortBRAMServerTile memoryServer
)(MemorySystem);
    interface InstructionMemoryServer instructionMemory;
        interface Get response;
            method ActionValue#(InstructionMemoryResponse) get;
                let response <- memoryServer.portA.response.get();
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(InstructionMemoryRequest request);
                memoryServer.portA.request.put(request);
            endmethod
        endinterface
    endinterface

    interface DataMemoryServer dataMemory;
        interface Get response;
            method ActionValue#(DataMemoryResponse) get;
                let response <- memoryServer.portB.response.get;
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(DataMemoryRequest request);
                memoryServer.portB.request.put(request);
            endmethod
        endinterface
    endinterface
endmodule
