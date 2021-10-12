import ClientServer::*;

typedef struct {
    (* always_ready, result="a_opcode" *)   Bit#(3) a_opcode;
    (* always_ready, result="a_param" *)    Bit#(3) a_param;
    (* always_ready, result="a_size" *)     Bit#(z) a_size;             // z = number of bits required for transfer size
    (* always_ready, result="a_source" *)   Bit#(o) a_source;           // o = number of bits to identify source
    (* always_ready, result="a_address" *)  Bit#(a) a_address;          // a = number of address bits
    (* always_ready, result="a_mask" *)     Bit#(w) a_mask;             // w = number of bytes in the mask
    (* always_ready, result="a_data" *)     Bit#(TMul#(w, 8)) a_data;

    // The below are part of the TileLink spec but are automatically provided by BlueSpec.
    // Bit#(1) a_valid
    // Bit#(1) a_ready
} TileLinkChannelARequest#(numeric type z, numeric type o, numeric type a, numeric type w) deriving(Bits, Eq);

typedef TileLinkChannelARequest(1, 1, 32, 4) TileLinkChannelARequest32;

typedef struct {
    (* always_ready, result="d_opcode" *)   Bit#(3) d_opcode;
    (* always_ready, result="d_param" *)    Bit#(2) d_param;
    (* always_ready, result="d_size" *)     Bit#(z) d_size;             // z = number of bits required for transfer size
    (* always_ready, result="d_source" *)   Bit#(o) d_source;           // o = number of bits to identify source
    (* always_ready, result="d_sink" *)     Bit#(i) d_sink;             // i = number of bits to identify sink
    (* always_ready, result="d_data" *)     Bit#(TMul#(w, 8)) d_data;
    (* always_ready, result="d_error" *)    Bit#(1) d_error;

    // The below are part of the TileLink spec but are automatically provided by BlueSpec.
    // Bit#(1) d_valid
    // Bit#(1) d_ready
} TileLinkChannelDResponse#(numeric type z, numeric type o, numeric type i, numeric type w) deriving(Bits, Eq);

typedef TileLinkChannelDResponse(1, 1, 1, 4) TileLinkChannelDResponset32;

typedef Client#(TileLinkChannelARequest32, TileLinkChannelDResponse32) TileLinkADClient32;
typedef Server#(TileLinkChannelARequest32, TileLinkChannelDResponse32) TileLinkADServer32;
