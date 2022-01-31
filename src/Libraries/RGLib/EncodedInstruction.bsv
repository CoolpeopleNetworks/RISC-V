import RGTypes::*;
import PipelineController::*;

typedef struct {
    Word fetchIndex;
    ProgramCounter programCounter;
    ProgramCounter predictedNextProgramCounter;
    PipelineEpoch pipelineEpoch;
    Word32 rawInstruction;
} EncodedInstruction deriving(Bits, Eq, FShow);
