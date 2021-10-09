import Core::*;

(* synthesize *)
module mkCoreTest(Empty);
    Core core <- mkCore;

    rule always;
        $display("mkCoreTest running...");
        $finish();
    endrule
endmodule
