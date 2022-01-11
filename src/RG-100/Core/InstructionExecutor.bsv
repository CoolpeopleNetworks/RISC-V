import ALU::*;
import FIFO::*;
import RVOperandForward::*;
import RVTypes::*;
import Instruction::*;

// ================================================================
// Exports
export InstructionExecutor (..), mkInstructionExecutor;

interface InstructionExecutor;
    method ExecutedInstruction execute(DecodedInstruction decodedInstruction);
endinterface

(* synthesize *)
module mkInstructionExecutor(InstructionExecutor);

    //
    // ALU
    //
    ALU alu <- mkALU();

    //
    // AUIPC
    //
    function ExecutedInstruction executeAUIPCInstruction(DecodedInstruction decodedInstruction);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Valid Writeback {
                rd: decodedInstruction.specific.AUIPCInstruction.rd,
                value: decodedInstruction.programCounter + decodedInstruction.specific.AUIPCInstruction.offset
            },
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    //
    // BRANCH
    //
    function ExecutedInstruction executeBRANCHInstruction(DecodedInstruction decodedInstruction);
        //!todo - instruction-address-misaligned exception if branch taken is *not* 32 bit aligned.
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Invalid,
            loadStore: tagged Invalid,
            exception: tagged Invalid            
        };
    endfunction

    //
    // JAL
    //
    function ExecutedInstruction executeJALInstruction(DecodedInstruction decodedInstruction);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Valid Writeback {
                rd: decodedInstruction.specific.JALInstruction.rd,
                value: decodedInstruction.programCounter + 4
            },
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    //
    // JALR
    //
    function ExecutedInstruction executeJALRInstruction(DecodedInstruction decodedInstruction);
        let immediate = signExtend(decodedInstruction.specific.JALRInstruction.offset);
        let effectiveAddress = decodedInstruction.rs1 + immediate;
        effectiveAddress[0] = 0;

        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Valid Writeback {
                rd: decodedInstruction.specific.JALRInstruction.rd,
                value: decodedInstruction.programCounter + 4
            },
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    //
    // LOAD
    //
    function ExecutedInstruction executeLOADInstruction(DecodedInstruction decodedInstruction);
        let offset = decodedInstruction.specific.LoadInstruction.offset;
        let effectiveAddress = decodedInstruction.rs1 + signExtend(offset);

        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Invalid,
            loadStore: tagged Valid LoadStore {
                writeEnable: 0,
                effectiveAddress: effectiveAddress,
                storeValue: ?   // Not used for LOAD
            },
            exception: tagged Invalid
        };
    endfunction

    //
    // STORE
    //
    function ExecutedInstruction executeSTOREInstruction(DecodedInstruction decodedInstruction);
        let offset = decodedInstruction.specific.LoadInstruction.offset;
        let effectiveAddress = decodedInstruction.rs1 + signExtend(offset);
        let writeEnable = case(decodedInstruction.specific.StoreInstruction.operator)
            SB: ('b0001 << effectiveAddress[1:0]);
            SH: ('b0011 << effectiveAddress[1:0]);
            SW: ('b1111);
        endcase;

        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Invalid,
            loadStore: tagged Valid LoadStore {
                writeEnable: 0,     // TODO: Fix!
                effectiveAddress: effectiveAddress,
                storeValue: decodedInstruction.rs2
            },
            exception: tagged Invalid
        };
    endfunction

    //
    // LUI
    //
    function ExecutedInstruction executeLUIInstruction(DecodedInstruction decodedInstruction);
        let data = 0;
        data[31:12] = decodedInstruction.specific.LUIInstruction.immediate;
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Valid Writeback {
                rd: decodedInstruction.specific.LUIInstruction.rd,
                value: data
            },
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    //
    // OP
    //
    function ExecutedInstruction executeOPInstruction(DecodedInstruction decodedInstruction);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Valid Writeback {
                rd: decodedInstruction.specific.ALUInstruction.rd,
                value: alu.execute(
                    decodedInstruction.rs1, 
                    decodedInstruction.rs2, 
                    decodedInstruction.specific.ALUInstruction.operator
                )
            },
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    //
    // OPIMM
    //
    function ExecutedInstruction executeOPIMMInstruction(DecodedInstruction decodedInstruction);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Valid Writeback {
                rd: decodedInstruction.specific.ALUInstruction.rd,
                value: alu.execute_immediate(
                    decodedInstruction.rs1, 
                    decodedInstruction.specific.ALUInstruction.immediate, 
                    decodedInstruction.specific.ALUInstruction.operator
                )
            },
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    //
    // SYSTEM
    //
    function ExecutedInstruction executeSYSTEMInstruction(DecodedInstruction decodedInstruction);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Invalid,
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    //
    // UNSUPPORTED
    //
    function ExecutedInstruction executeUNSUPPORTEDInstruction(DecodedInstruction decodedInstruction);
        return ExecutedInstruction {
            decodedInstruction: decodedInstruction,
            writeBack: tagged Invalid,
            loadStore: tagged Invalid,
            exception: tagged Invalid
        };
    endfunction

    method ExecutedInstruction execute(DecodedInstruction decodedInstruction);
        return case(decodedInstruction.instructionType)
            AUIPC:  return executeAUIPCInstruction(decodedInstruction);
            BRANCH: return executeBRANCHInstruction(decodedInstruction);
            JAL:    return executeJALInstruction(decodedInstruction);
            JALR:   return executeJALRInstruction(decodedInstruction);
            OP:     return executeOPInstruction(decodedInstruction);
            OPIMM:  return executeOPIMMInstruction(decodedInstruction);
            LUI:    return executeLUIInstruction(decodedInstruction);
            LOAD:   return executeLOADInstruction(decodedInstruction);
            STORE:  return executeSTOREInstruction(decodedInstruction);
            SYSTEM: return executeSYSTEMInstruction(decodedInstruction);
            UNSUPPORTED: return executeUNSUPPORTEDInstruction(decodedInstruction);
        endcase;
    endmethod
endmodule
