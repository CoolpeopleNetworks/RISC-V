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
    DualPortBRAMServerTile memoryServer,
    Integer memoryBaseAddress
)(MemorySystem);
    Word baseAddress = fromInteger(memoryBaseAddress);
    Word highMemoryAddress = baseAddress + fromInteger(memoryServer.getMemorySize);

    interface InstructionMemoryServer instructionMemory;
        interface Get response;
            method ActionValue#(InstructionMemoryResponse) get;
                let response <- memoryServer.portA.response.get();
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(InstructionMemoryRequest request);
                if (request.a_address >= baseAddress && 
                    request.a_address < highMemoryAddress) begin
                    request.a_address = request.a_address - baseAddress;
                end else begin
                    request.a_corrupt = True;
                end
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
                if (request.a_address >= baseAddress && 
                    request.a_address < highMemoryAddress) begin
                    request.a_address = request.a_address - baseAddress;
                end else begin
                    request.a_corrupt = True;
                end

                memoryServer.portB.request.put(request);
            endmethod
        endinterface
    endinterface
endmodule
