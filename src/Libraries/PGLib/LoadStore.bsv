import PGTypes::*;
import Exception::*;

//
// LoadRequest
//
// Structure containing information about a request to load data
// from memory.
//
typedef struct {
    RegisterIndex rd;
    Word effectiveAddress;
    RVLoadOperator operator;
} LoadRequest deriving(Bits, Eq, FShow);

//
// StoreRequest
//
// Structure containing information about a request to store data
// to memory.
//
typedef struct {
    Word wordAddress;               // XLEN aligned
    Bit#(TDiv#(XLEN, 8)) byteEnable;
    Word value;
} StoreRequest deriving(Bits, Eq, FShow);

function Result#(StoreRequest, Exception) getStoreRequest(
    RVStoreOperator storeOperator,
    Word effectiveAddress,
    Word value);

    Result#(StoreRequest, Exception) result = 
        tagged Error tagged ExceptionCause extend(pack(ILLEGAL_INSTRUCTION));

    Bit#(XLEN) shift = fromInteger(valueOf(TLog#(TDiv#(XLEN,8))));
    Bit#(XLEN) mask = ~((1 << shift) - 1);

    // Determine the *word* address of the store request.
    let wordAddress = effectiveAddress & mask;

    // Determine how much to shift bytes by to find the right byte address inside a word.
    let leftShiftBytes = effectiveAddress - wordAddress;

    let storeRequest = StoreRequest {
        wordAddress: wordAddress,
        byteEnable: ?,
        value: ?
    };

    case (storeOperator)
        // Byte
        pack(SB): begin
            storeRequest.byteEnable = ('b1 << leftShiftBytes);
            storeRequest.value = (value & 'hFF) << (8 * leftShiftBytes);

            result = tagged Success storeRequest;
        end
        // Half-word
        pack(SH): begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.byteEnable = ('b11 << leftShiftBytes);
                storeRequest.value = (value & 'hFFFF) << (8 * leftShiftBytes);

                result = tagged Success storeRequest;
            end
        end
        // Word
        pack(SW): begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.byteEnable = ('b1111 << leftShiftBytes);
                storeRequest.value = (value & 'hFFFF_FFFF) << (8 * leftShiftBytes);

                result = tagged Success storeRequest;
            end
        end
`ifdef RV64
        // Double-word
        pack(SD): begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.byteEnable = 'b1111_1111;
                storeRequest.value = value;

                result = tagged Success storeRequest;
            end
        end
`endif
    endcase

    return result;
endfunction
