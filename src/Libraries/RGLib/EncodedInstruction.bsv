import RGTypes::*;
import PipelineController::*;

typedef struct {
    ProgramCounter programCounter;
    PipelineEpoch pipelineEpoch;
    Word32 rawInstruction;
} EncodedInstruction deriving(Bits, Eq, FShow);
