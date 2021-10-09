import Core::*;

(* synthesize *)
module mkCoreTest(Empty);
    Core core <- mkCore;

    rule test;
        $display("mkCoreTest running...");
        $finish();
    endrule
endmodule
