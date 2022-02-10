import RGTypes::*;
import BRAMServerTile::*;
import MemorySystem::*;

import DebugModule::*;
import RegFile::*;
import RG10xCore::*;
import MemorySystem::*;

(* synthesize *)
module mkSimulator(Empty);
    // BRAM Server Tile
    DualPortBRAMServerTile memory <- mkBRAMServerTileFromFile(32, "MemoryContents.hex");

    // Memory System
    MemorySystem memorySystem <- mkMemorySystem(memory);

    // Debug Module
    DebugModule debugModule <- mkDebugModule();

    // Core
    RG100Core core <- mkRG100Core(debugModule, 0, memorySystem.instructionMemory, memorySystem.dataMemory, True /* Disable Pipelining */);
    Reg#(Bool) initialized <- mkReg(False);

    (* fire_when_enabled *)
    rule initialization(initialized == False && core.state == RESET);
        initialized <= True;

        $display("----------------");
        $display("RG-100 Simulator");
        $display("----------------");

        core.start();
    endrule
endmodule
