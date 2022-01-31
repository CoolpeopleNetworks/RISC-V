import RGTypes::*;
import PipelineController::*;

typedef enum {
    ALU,
    BRANCH,
    COPY_IMMEDIATE, // copies immediate value to register rd (Used by LUI and AUIPC).
    JUMP,
    JUMP_INDIRECT,
    LOAD,
    STORE,
    SYSTEM,
    UNSUPPORTED_OPCODE
} Opcode deriving(Bits, Eq, FShow);

typedef struct {
    Word fetchIndex;
    PipelineEpoch epoch;
    Opcode opcode;
    ProgramCounter programCounter;
    ProgramCounter predictedNextProgramCounter;
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
