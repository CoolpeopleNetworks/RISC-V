import ALU::*;
import InstructionDecoder::*;
import Instruction::*;
import RGTypes::*;

(* synthesize *)
module mkInstructionDecoderTests(Empty);
    Reg#(Word) testNumber <- mkReg(0);

    // rule test;
    //     $display("Instruction Decoder - Running test %0d", testNumber);
    //     case (testNumber)
    //         0: begin
    //             let decodedInstruction = decodeInstruction(0);
    //             if (decodedInstruction.instructionType != UNSUPPORTED) begin
    //                 $display("Instruction Decoder - Test %0d failed - Expected %0d, Found: %0d", testNumber, UNSUPPORTED, decodedInstruction.instructionType);
    //                 $fatal(); 
    //             end
    //         end
    //         1: begin
    //             // ADDI
    //             let decodedInstruction = decodeInstruction('b000000000000_00010_000_00100_0010011);
    //             if (decodedInstruction.instructionType != OPIMM) begin
    //                 $display("Instruction Decoder - Test %0d failed - Expected OPIMM, Found: %0d", testNumber, decodedInstruction.instructionType);
    //                 $fatal(); 
    //             end

    //             if (decodedInstruction.rs1 != 2) begin
    //                 $display("Instruction Decoder - Test %0d failed - Expected RS1 = 2, Found: %0d", testNumber, decodedInstruction.rs2);
    //                 $fatal(); 
    //             end

    //             if (decodedInstruction.specific.ALUInstruction.rd != 4) begin
    //                 $display("Instruction Decoder - Test %0d failed - Expected RD = 4, Found: %0d", testNumber, decodedInstruction.specific.ALUInstruction.rd);
    //                 $fatal(); 
    //             end

    //             if (decodedInstruction.specific.ALUInstruction.operator != ADD) begin
    //                 $display("Instruction Decoder - Test %0d failed - Expected Operator = ADD, Found: %0d", testNumber, decodedInstruction.specific.ALUInstruction.operator);
    //                 $fatal(); 
    //             end
    //         end
    //         default: begin
    //             $display("[%0d] --- PASSED", testNumber);
    //             $finish();
    //         end
    //     endcase

    //     $display("Instruction Decoder - Test %0d OK", testNumber);
    //     testNumber <= testNumber + 1;
    // endrule
endmodule
