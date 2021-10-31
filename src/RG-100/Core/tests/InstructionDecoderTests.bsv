import InstructionDecoder::*;
import Instruction::*;
import Common::*;

(* synthesize *)
module mkInstructionDecoderTests(Empty);
    InstructionDecoder instructionDecoder <- mkInstructionDecoder();
    Reg#(Word) testNumber <- mkReg(0);

    rule test;
        case (testNumber)
            0: begin
                let decodedInstruction = instructionDecoder.decode(0);
                if (decodedInstruction.instructionType != UNSUPPORTED) begin
                    $display("Instruction Decoder - Test %0d failed - Expected UNSUPPORTED, Found: %0d", testNumber, decodedInstruction.instructionType);
                    $fatal(); 
                end
            end
            default: begin
                $display("--- PASSED");
                $finish();
            end
        endcase
        testNumber <= testNumber + 1;
    endrule
endmodule
