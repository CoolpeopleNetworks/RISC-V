import RGTypes::*;

interface BypassUnit;
    method Action setRegisterIndex(RegisterIndex registerIndex);
    method Action addValueFromExecutionUnit(Word value);
    method Action addValueFromMemoryAccessUnit(Word value);

    method Bool search(RegisterIndex rs1, RegisterIndex rs2);

    method Maybe#(Word) getBypassedValue(RegisterIndex rix);
endinterface

module mkBypassUnit(BypassUnit);
    RWire#(RegisterIndex) registerIndex <- mkRWireSBR();
    RWire#(Word) registerFromExecutionUnit <- mkRWireSBR();
    RWire#(Word) registerFromMemoryAccessUnit <- mkRWireSBR();

    method Action setRegisterIndex(RegisterIndex rd);
        registerIndex.wset(rd);
    endmethod

    method Action addValueFromExecutionUnit(Word value);
        registerFromExecutionUnit.wset(value);
    endmethod

    method Action addValueFromMemoryAccessUnit(Word value);
        registerFromMemoryAccessUnit.wset(value);
    endmethod

    method Bool search(RegisterIndex rs1, RegisterIndex rs2);
        Bool found = False;
        let rd = registerIndex.wget();
        if (isValid(rd)) begin
            let bypassIndex = unJust(rd);
            if (rs1 == bypassIndex || rs2 == bypassIndex) begin
                found = (!isValid(registerFromExecutionUnit.wget()) || !isValid(registerFromMemoryAccessUnit.wget()));
            end
        end

        return found;
    endmethod

    method Maybe#(Word) getBypassedValue(RegisterIndex rdCheck);
        Maybe#(Word) result = tagged Invalid;
        let rd = registerIndex.wget();
        if (isValid(rd) && unJust(rd) == rdCheck) begin
            if (isValid(registerFromExecutionUnit.wget())) begin
                result = registerFromExecutionUnit.wget();
            end else if (isValid(registerFromMemoryAccessUnit.wget())) begin
                result = registerFromMemoryAccessUnit.wget();
            end
        end

        return result;
    endmethod
endmodule
