import RGTypes::*;

import CSRFile::*;
import ExceptionController::*;

import Assert::*;

typedef enum {
    INIT,
    VERIFY_INIT,
    TEST,
    VERIFY_TEST,
    COMPLETE
} State deriving(Bits, Eq, FShow);

(* synthesize *)
module mkExceptionController_test(Empty);
    Reg#(State) state <- mkReg(INIT);

    CSRFile csrFile <- mkCSRFile();
    ExceptionController exceptionController <- mkExceptionController(csrFile);

    Word exceptionVector = 'h8000;

    rule init(state == INIT);
        let succeeded <- csrFile.write0(PRIVILEGE_LEVEL_USER, pack(MTVEC), exceptionVector);
        dynamicAssert(succeeded == False, "Attempt to write MTVEC in user mode should fail.");

        succeeded <- csrFile.write0(PRIVILEGE_LEVEL_MACHINE, pack(MTVEC), exceptionVector);
        dynamicAssert(succeeded == True, "Attempt to write MTVEC in machine mode should succeed.");
        state <= VERIFY_INIT;
    endrule

    rule verifyInit(state == VERIFY_INIT);
        let result = csrFile.read0(PRIVILEGE_LEVEL_MACHINE, pack(MTVEC));
        dynamicAssert(isValid(result), "Reading MTVEC in machine mode should succeed.");
        dynamicAssert(unJust(result) == exceptionVector, "Reading MTVEC should contain value written");

        state <= TEST;
    endrule

    rule beginException(state == TEST);
        //let receivedExceptionVector <- exceptionController.beginException(PRIVILEGE_LEVEL_USER, 'h4000, )

        state <= VERIFY_TEST;
    endrule

    rule endException(state == VERIFY_TEST);
        state <= COMPLETE;
    endrule

    rule complete(state == COMPLETE);
        $display("--- NOT IMPLEMENTED");
        $finish();
    endrule
endmodule
