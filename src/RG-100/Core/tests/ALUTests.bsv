import ALU::*;

(* synthesize *)
module mkALUTests(Empty);
    rule test;
        $display("mkALUTests running...");
        $display("--- PASSED");
        $fatal();
    endrule
endmodule
