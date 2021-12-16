import RVTypes::*;

typedef enum {
    BYPASS_STATE_EMPTY,
    BYPASS_STATE_REGISTER_KNOWN,
    BYPASS_STATE_VALUE_AVAILABLE
} RVBypassState deriving(Bits, Eq);

typedef struct {
    RVBypassState state;
    RegisterIndex rd;
    Word value;
} RVBypass deriving(Bits, Eq);
