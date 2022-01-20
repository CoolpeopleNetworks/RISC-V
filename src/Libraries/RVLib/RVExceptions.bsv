typedef enum {
    INSTRUCTION_ADDRESS_MISALIGNED = 0,
    INSTRUCTION_ACCESS_FAULT = 1,
    ILLEGAL_INSTRUCTION = 2,
    BREAKPOINT = 3,
    LOAD_ADDRESS_MISALIGNED = 4,
    LOAD_ACCESS_FAULT = 5,
    STORE_ADDRESS_MISALIGNED = 6,
    STORE_ADDRESS_FAULT = 7,
    ENVIRONMENT_CALL_FROM_U_MODE = 8,
    ENVIRONMENT_CALL_FROM_S_MODE = 9,
    // RESERVED = 10
    ENVIRONMENT_CALL_FROM_M_MODE = 11,
    INSTRUCTION_PAGE_FAULT = 12,
    LOAD_PAGE_FAULT = 13,
    // RESERVED = 14,
    STORE_PAGE_FAULT = 15
    // RESERVED = 16-23
    // CUSTOM USE = 24-31
    // RESERVED = 32-47
    // CUSTOM USE = 48-63
    // RESERVER >= 64
} ExceptionType deriving(Bits, Eq);
