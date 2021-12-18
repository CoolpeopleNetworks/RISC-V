import RVTypes::*;

typedef struct {
    RegisterIndex rd;
    Maybe#(Word) value;     // Valid if the value is available (not needing to be loaded from memory)
} RVRegisterBypass deriving(Bits, Eq);
