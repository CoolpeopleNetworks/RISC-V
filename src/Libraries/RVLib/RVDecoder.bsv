import RVTypes::*;
import RVALU::*;
import RVInstruction::*;

typedef struct {
    RVOpcode opcode;
    ProgramCounter programCounter;
    RVALUOperator aluOperator;
    RVLoadOperator loadOperator;
    RVBranchOperator branchOperator;
    ProgramCounter predictedBranchTarget;
    RegisterIndex rd;
    RegisterIndex rs1;
    RegisterIndex rs2;
    Maybe#(Word) immediate;
} RVDecodedInstruction deriving(Bits, Eq, FShow);

interface RVDecoder;
    method RVDecodedInstruction decode(ProgramCounter programCounter, Word instruction);
endinterface

(* synthesize *)
module mkRVDecoder(RVDecoder);

    function Bool isValidLoadInstruction(Bit#(3) func3);
        return (func3 == pack(UNSUPPORTED_LOAD_OPERATOR_011) ||
                func3 == pack(UNSUPPORTED_LOAD_OPERATOR_110) ||
                func3 == pack(UNSUPPORTED_LOAD_OPERATOR_111) ? False : True);
    endfunction

    function Bool isValidStoreInstruction(Bit#(3) func3);
        return (func3 < 2 ? True : False);
    endfunction

    function Bool isValidBranchInstruction(Bit#(3) func3);
        return (func3 == pack(UNSUPPORTED_BRANCH_OPERATOR_010) || 
                func3 == pack(UNSUPPORTED_BRANCH_OPERATOR_011) ? False : True);
    endfunction

    method RVDecodedInstruction decode(ProgramCounter programCounter, Word instruction);
        let opcode = instruction[6:0];
        let rd = instruction[11:7];
        let func3 = instruction[14:12];
        let rs1 = instruction[19:15];
        let rs2 = instruction[24:20];
        let shamt = instruction[24:20];  // same bits as rs2
        let func7 = instruction[31:25];
        let immediate31_20 = signExtend(instruction[31:20]); // same bits as {func7, rs2}

        let decodedInstruction = RVDecodedInstruction {
            opcode: UNSUPPORTED_OPCODE,
            programCounter: programCounter,
            aluOperator: unpack({func7, func3}),
            loadOperator: unpack(func3),
            branchOperator: ?,
            predictedBranchTarget: ?,
            rd: rd,
            rs1: rs1,
            rs2: rs2,
            immediate: tagged Invalid
        };

        case(opcode)
            //
            // LOAD
            //
            7'b0000011: begin
                if (isValidLoadInstruction(func3)) begin
                    decodedInstruction.opcode = LOAD;
                    decodedInstruction.immediate = tagged Valid immediate31_20;
                end
            end
            //
            // OP-IMM
            //
            7'b0010011: begin   
                // Check for shift instructions
                if (func3[1:0] == 2'b01) begin
                    if (func7 == 7'b0000000 || func7 == 7'b0100000) begin
                        decodedInstruction.opcode = ALU;
                        decodedInstruction.immediate = tagged Valid extend(shamt);
                    end
                end else begin
                    decodedInstruction.opcode = ALU;
                    decodedInstruction.immediate = tagged Valid immediate31_20;
                end
            end
            //
            // AUIPC
            //
            7'b0010111: begin
                decodedInstruction.opcode = COPY_IMMEDIATE;
                decodedInstruction.immediate = tagged Valid ({instruction[31:12], 12'b0} + programCounter);
            end
            //
            // STORE
            //
            7'b0100011: begin
                if (isValidStoreInstruction(func3)) begin
                    decodedInstruction.opcode = STORE;
                    decodedInstruction.immediate = tagged Valid (signExtend({instruction[31:25], instruction[11:7]}));
                end
            end
            //
            // OP
            // 
            7'b0110011: begin
                if (func7 == 7'b0000000 || (func7 == 7'b0100000 && (func3 == 3'b000 || func3 == 3'b101)))   
                    decodedInstruction.opcode = ALU;
            end
            //
            // LUI
            //
            7'b0110111: begin
                decodedInstruction.opcode = COPY_IMMEDIATE;
                decodedInstruction.immediate = tagged Valid ({instruction[31:12], 12'b0});
            end
            //
            // BRANCH
            //
            7'b1100011: begin
                if (isValidBranchInstruction(func3)) begin
                    Word immediate = signExtend({
                        instruction[31],        // 1 bit
                        instruction[7],         // 1 bit
                        instruction[30:25],     // 6 bits
                        instruction[11:8],      // 4 bits
                        1'b0                    // 1 bit
                    });
                    let branchTarget = programCounter + immediate;
                    Bool branchDirectionNegative = (msb(immediate) == 1'b1 ? True : False);
                    decodedInstruction.opcode = BRANCH;
                    decodedInstruction.immediate = tagged Valid immediate;
                    decodedInstruction.predictedBranchTarget = 
                        (branchDirectionNegative ? branchTarget : (programCounter + 4));
                end
            end
        endcase

        return decodedInstruction;
    endmethod

endmodule
