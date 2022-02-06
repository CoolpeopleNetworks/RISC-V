import RGTypes::*;

import CSRFile::*;
import Exception::*;

import Assert::*;

interface ExceptionController;
    method ActionValue#(ProgramCounter) beginException(RVPrivilegeLevel privilegeLevel, ProgramCounter exceptionProgramCounter, Exception exception);
    method Action endException();
endinterface

module mkExceptionController#(
    CSRFile csrFile
)(ExceptionController);
    Reg#(Maybe#(Exception)) currentException <- mkReg(tagged Invalid);

    method ActionValue#(ProgramCounter) beginException(RVPrivilegeLevel privilegeLevel, ProgramCounter exceptionProgramCounter, Exception exception);
        if (isValid(currentException) && unJust(currentException).cause == exception.cause) begin
            $display("Exception during handling of exception...halting");
            $fatal();
        end

        currentException <= tagged Valid exception;
        return 'hdeadbeef;
    endmethod

    method Action endException;
        dynamicAssert(isValid(currentException), "Attempted to call endException when not handling exception");
        currentException <= tagged Invalid;
    endmethod
endmodule
