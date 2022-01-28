import RVTypes::*;
import RVInstruction::*;

typedef struct {
    PipelineEpoch epoch;
    RVOpcode opcode;
    ProgramCounter programCounter;
    RVALUOperator aluOperator;
    RVLoadOperator loadOperator;
    RVStoreOperator storeOperator;
    RVBranchOperator branchOperator;
    RVSystemOperator systemOperator;
    ProgramCounter predictedBranchTarget;

    Maybe#(RegisterIndex) rd;
    Maybe#(RegisterIndex) rs1;
    Maybe#(RegisterIndex) rs2;
    Maybe#(Word) immediate;

    Word rs1Value;
    Word rs2Value;
} DecodedInstruction deriving(Bits, Eq, FShow);
