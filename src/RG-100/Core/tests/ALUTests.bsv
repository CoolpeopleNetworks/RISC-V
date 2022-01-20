import RVALU::*;
import RVTypes::*;

(* synthesize *)
module mkALUTests(Empty);
    RVALU alu <- mkRVALU();
    Reg#(Word) testNumber <- mkReg(0);

    rule test;
        let operand1 = 0;
        let operand2 = 0;
        let expected = 0;
        let operator = ADD;

        case (testNumber)
            0: begin
                operator = ADD;
                operand1 = 10;
                operand2 = 3;
                expected = 13;
            end
            1: begin
                operator = AND;
                operand1 = 10;
                operand2 = 3;
                expected = 2;
            end
            2: begin
                operator = OR;
                operand1 = 2;
                operand2 = 4;
                expected = 6;
            end
            3: begin
                operator = SLT;
                operand1 = 2;
                operand2 = 4;
                expected = 1;
            end
            4: begin
                operator = SLT;
                operand1 = 4;
                operand2 = 2;
                expected = 0;
            end
            5: begin
                operator = SLT;
                operand1 = -4;
                operand2 = -5;
                expected = 0;
            end
            6: begin
                operator = SLT;
                operand1 = -5;
                operand2 = -4;
                expected = 1;
            end
            7: begin
                operator = SLTU;
                operand1 = 2;
                operand2 = 4;
                expected = 1;
            end
            8: begin
                operator = SLTU;
                operand1 = 4;
                operand2 = 2;
                expected = 0;
            end
            9: begin
                operator = SLL;
                operand1 = 11;
                operand2 = 2;
                expected = 44;
            end
            10: begin
                operator = SRA;
                operand1 = -44;
                operand2 = 2;
                expected = -11;
            end
            11: begin
                operator = SRL;
                operand1 = 44;
                operand2 = 2;
                expected = 11;
            end
            12: begin
                operator = SUB;
                operand1 = 44;
                operand2 = 11;
                expected = 33;
            end
            13: begin
                operator = XOR;
                operand1 = 'b0110;
                operand2 = 'b1100;
                expected = 'b1010;
            end
            default: begin
                $display("--- PASSED");
                $finish();
            end
        endcase

        let actual = alu.execute(operand1, operand2, pack(operator));
        if (actual != expected) begin 
            Int#(32) signedExpected = unpack(pack(expected));
            Int#(32) signedActual = unpack(pack(actual));
            $display("ALU - Test %0d failed, expected %0d (%0d) received %0d (%0d)", testNumber, expected, signedExpected, actual, signedActual);
            $fatal(); 
        end

        testNumber <= testNumber + 1;
    endrule
endmodule
