import RVTypes::*;

typedef enum {
    BYPASS_STATE_EMPTY,
    BYPASS_STATE_REGISTER_KNOWN,
    BYPASS_STATE_VALUE_AVAILABLE
} RVRegisterBypassState deriving(Bits, Eq);

typedef struct {
    RVRegisterBypassState state;
    RegisterIndex rd;
    Word value;
} RVRegisterBypass deriving(Bits, Eq);
