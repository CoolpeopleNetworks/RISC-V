import ClientServer::*;

typedef struct {
    Bit#(3) a_opcode;
    Bit#(3) a_param;
    Bit#(z) a_size;             // z = number of bits required for transfer size
    Bit#(o) a_source;           // o = number of bits to identify source
    Bit#(a) a_address;          // a = number of address bits
    Bit#(w) a_mask;             // w = number of bytes in the mask
    Bit#(TMul#(w, 8)) a_data;

    // The below are part of the TileLink spec but are automatically provided by BlueSpec.
    // Bit#(1) a_valid
    // Bit#(1) a_ready
} TileLinkChannelARequest#(numeric type z, numeric type o, numeric type a, numeric type w) deriving(Bits, Eq);

typedef TileLinkChannelARequest(6, 1, 32, 4) TileLinkChannelARequest32;

typedef struct {
    Bit#(3) d_opcode;
    Bit#(2) d_param;
    Bit#(z) d_size;             // z = number of bits required for transfer size
    Bit#(o) d_source;           // o = number of bits to identify source
    Bit#(i) d_sink;             // i = number of bits to identify sink
    Bit#(TMul#(w, 8)) d_data;
    Bit#(1) d_error;

    // The below are part of the TileLink spec but are automatically provided by BlueSpec.
    // Bit#(1) d_valid
    // Bit#(1) d_ready
} TileLinkChannelDResponse#(numeric type z, numeric type o, numeric type i, numeric type w) deriving(Bits, Eq);

typedef TileLinkChannelDResponse(6, 1, 1, 4) TileLinkChannelDResponset32;

typedef Client#(TileLinkChannelARequest32, TileLinkChannelDResponse32) TileLinkADClient32;
typedef Server#(TileLinkChannelARequest32, TileLinkChannelDResponse32) TileLinkADServer32;
