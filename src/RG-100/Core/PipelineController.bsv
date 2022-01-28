import RVTypes::*;
import Vector::*;

interface PipelineController;
    method PipelineEpoch stageEpoch(Integer index);
    method Bool isCurrentEpoch(Integer stageIndex, PipelineEpoch check);
    method Action flush0;
    method Action flush1;
endinterface

module mkPipelineController#(
    Integer stageCount
)(PipelineController);
    Vector#(10, Array#(Reg#(PipelineEpoch))) stageEpochs <- replicateM(mkCReg(3, 0));

    method PipelineEpoch stageEpoch(Integer index);
        return stageEpochs[index][2];
    endmethod

    method Bool isCurrentEpoch(Integer stageIndex, PipelineEpoch check);
        return (check == stageEpochs[stageIndex][2]);
    endmethod

    method Action flush0;
        for (Integer i = 0; i < stageCount; i = i + 1) begin
            stageEpochs[i][0] <= stageEpochs[i][0] + 1; 
        end
    endmethod

    method Action flush1;
        for (Integer i = 0; i < stageCount; i = i + 1) begin
            stageEpochs[i][1] <= stageEpochs[i][1] + 1; 
        end
    endmethod
endmodule