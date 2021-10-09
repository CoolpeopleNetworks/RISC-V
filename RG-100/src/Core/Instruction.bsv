import Common::*;

//
// Instruction
//
typedef union tagged {
    Word RawInstruction;

    struct {
        Bit#(7) opcode;
        Bit#(25) data;
    } Common;

    // RV32I - R-type
    struct {
        Bit#(7) opcode;
        RegisterIndex destination;
        Bit#(3) func3;
        RegisterIndex source1;
        RegisterIndex source2;
        Bit#(7) func7;
    } RtypeInstruction;

    // RV32I - I-type
    struct {
        Bit#(7) opcode;
        RegisterIndex destination;
        Bit#(3) func3;
        RegisterIndex source1;
        Bit#(12) immediate;
    } ItypeInstruction;

    // RV32I - S-type
    struct {
        Bit#(7) opcode;
        Bit#(5) immediateLow;
        Bit#(3) func3;
        RegisterIndex source1;
        RegisterIndex source2;
        Bit#(7) immediateHigh;
    } StypeInstruction;

    // RV32I - B-type
    struct {
        Bit#(7) opcode;
        Bit#(1) immediate11;
        Bit#(4) immediate4_1;
        Bit#(3) func3;
        RegisterIndex source1;
        RegisterIndex source2;
        Bit#(6) immediate10_5;
        Bit#(1) immediate12;
    } BtypeInstruction;

    // RV32I - U-type
    struct {
        Bit#(7) opcode;
        RegisterIndex destination;
        Bit#(20) immediate31_12;
    } UtypeInstruction;

    // RV32I - J-type
    struct {
        Bit#(7) opcode;
        RegisterIndex returnSave;
        Bit#(8) immediate19_12;
        Bit#(1) immediate11;
        Bit#(10) immediate10_1;
        Bit#(1) immediate20;
    } JtypeInstruction;
} Instruction deriving(Bits, Eq);
