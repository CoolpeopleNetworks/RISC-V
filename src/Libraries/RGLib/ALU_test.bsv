import ALU::*;

(* synthesize *)
module mkALU_test(Empty);
    rule runme;
        $display("--- PASS");
        $finish();
    endrule
endmodule
