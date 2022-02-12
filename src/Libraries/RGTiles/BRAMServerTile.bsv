import RGTypes::*;
import TileLink::*;

import BRAM::*;
import FIFO::*;

interface DualPortBRAMServerTile;
    interface TileLinkADServer32 portA;
    interface TileLinkADServer32 portB;

    method Integer getMemorySize();
endinterface

module mkBRAMServerTileFromFile#(
    Integer sizeInKb,
    String memoryContents
)(DualPortBRAMServerTile);
    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = 1024 * sizeInKb;
    cfg.loadFormat = tagged Hex memoryContents;
    BRAM2PortBE#(Word32, Word32, 4) bram <- mkBRAM2ServerBE(cfg);

    FIFO#(TileLinkChannelARequest32) requestsA <- mkFIFO;
    FIFO#(TileLinkChannelDResponse32) responsesA <- mkFIFO;
    Reg#(Bool) lastRequestIsWriteA <- mkReg(False);
    Reg#(Bool) requestInFlightA <- mkReg(False);

    Word validAddressBits = fromInteger((1024 * sizeInKb) - 1);

    rule bramRequestA(!requestInFlightA);
        let request = requestsA.first();
        requestsA.deq;

        let wordAddress = request.a_address >> 2;
        let aligned = (request.a_address & 3) == 0 ? True : False;
        let oob = (request.a_address & ~validAddressBits) != 0;

        if (!oob && !request.a_corrupt && aligned && request.a_opcode == pack(A_GET)) begin
            bram.portA.request.put(BRAMRequestBE {
                writeen: 0,
                responseOnWrite: False,
                address: wordAddress,
                datain: ?
            });
            lastRequestIsWriteA <= False;
            requestInFlightA <= True;
        end else if (!oob && !request.a_corrupt && aligned && request.a_opcode == pack(A_PUT_FULL_DATA)) begin
            bram.portA.request.put(BRAMRequestBE {
                writeen: request.a_mask,
                responseOnWrite: True,
                address: wordAddress,
                datain: request.a_data
            });
            lastRequestIsWriteA <= True;
            requestInFlightA <= True;
        end else begin
            responsesA.enq(TileLinkChannelDResponse32 {
                d_opcode: pack(D_ACCESS_ACK_DATA),
                d_param: 0,
                d_size: 0,
                d_source: 0,
                d_sink: 0,
                d_denied: True,
                d_data: ?,
                d_corrupt: request.a_corrupt
            });
        end
    endrule

    rule bramResponseA(requestInFlightA);
        let response <- bram.portA.response.get;
        Word data = extend(response);

        requestInFlightA <= False;

        responsesA.enq(TileLinkChannelDResponse32 {
            d_opcode: lastRequestIsWriteA ? pack(D_ACCESS_ACK) : pack(D_ACCESS_ACK_DATA),
            d_param: 0,
            d_size: lastRequestIsWriteA ? 0 : 1,
            d_source: 0,
            d_sink: 0,
            d_denied: False,
            d_data: lastRequestIsWriteA ? 0 : data,
            d_corrupt: False
        });
    endrule

    FIFO#(TileLinkChannelARequest32) requestsB <- mkFIFO;
    FIFO#(TileLinkChannelDResponse32) responsesB <- mkFIFO;
    Reg#(Bool) lastRequestIsWriteB <- mkReg(False);
    Reg#(Bool) requestInFlightB <- mkReg(False);

    rule bramRequestB(!requestInFlightB);
        let request = requestsB.first();
        requestsB.deq;

        let wordAddress = request.a_address >> 2;
        let aligned = (request.a_address & 3) == 0 ? True : False;

        if (!request.a_corrupt && aligned && request.a_opcode == pack(A_GET)) begin
            bram.portB.request.put(BRAMRequestBE {
                writeen: 0,
                responseOnWrite: False,
                address: wordAddress,
                datain: ?
            });
            lastRequestIsWriteB <= False;
            requestInFlightB <= True;
        end else if (!request.a_corrupt && aligned && request.a_opcode == pack(A_PUT_FULL_DATA)) begin
            bram.portB.request.put(BRAMRequestBE {
                writeen: request.a_mask,
                responseOnWrite: True,
                address: wordAddress,
                datain: request.a_data
            });
            lastRequestIsWriteB <= True;
            requestInFlightB <= True;
        end else begin
            responsesB.enq(TileLinkChannelDResponse32 {
                d_opcode: pack(D_ACCESS_ACK_DATA),
                d_param: 0,
                d_size: 0,
                d_source: 0,
                d_sink: 0,
                d_denied: True,
                d_data: ?,
                d_corrupt: request.a_corrupt
            });
        end
    endrule

    rule bramResponseB(requestInFlightB);
        let response <- bram.portB.response.get;
        Word data = extend(response);

        requestInFlightB <= False;

        responsesB.enq(TileLinkChannelDResponse32 {
            d_opcode: lastRequestIsWriteB ? pack(D_ACCESS_ACK) : pack(D_ACCESS_ACK_DATA),
            d_param: 0,
            d_size: lastRequestIsWriteB ? 0 : 1,
            d_source: 0,
            d_sink: 0,
            d_denied: False,
            d_data: lastRequestIsWriteB ? 0 : data,
            d_corrupt: False
        });
    endrule

    interface TileLinkADServer32 portA;
        interface Get response;
            method ActionValue#(TileLinkChannelDResponse32) get;
                let response = responsesA.first();
                responsesA.deq;

                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkChannelARequest32 request);
                requestsA.enq(request);
            endmethod
        endinterface
    endinterface

    interface TileLinkADServer32 portB;
        interface Get response;
            method ActionValue#(TileLinkChannelDResponse32) get;
                let response = responsesB.first();
                responsesB.deq;

                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkChannelARequest32 request);
                requestsB.enq(request);
            endmethod
        endinterface
    endinterface

    method Integer getMemorySize;
        return 1024 * sizeInKb;
    endmethod
endmodule
