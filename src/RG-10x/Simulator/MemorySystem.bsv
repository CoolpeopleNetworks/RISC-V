import RGTypes::*;
import MemoryInterfaces::*;
import FIFO::*;

export GetPut::*, MemorySystem(..), mkMemorySystemFromFile, MemoryInterfaces::*;

interface MemorySystem;
    interface InstructionMemoryServer instructionMemory;
    interface DataMemoryServer dataMemory;
endinterface

`ifdef RV64
typedef struct {
    Word32 lower;
    Word32 upper;
    Word wordAddress;
    Bit#(8) byteEnable;
} WriteData deriving(Bits, Eq);
`endif

module mkMemorySystemFromFile#(
    Integer sizeInKb,
    String memoryContents
)(MemorySystem);
    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = 1024 * sizeInKb;
    cfg.loadFormat = tagged Hex memoryContents;
    BRAM2PortBE#(Word32, Word32, 4) bram <- mkBRAM2ServerBE(cfg);

    FIFO#(Word) requestAddressQueue <- mkFIFO();

//
// For RV64 we need multiple cycles to accumulate the data sent to the
// BRAM.
//
`ifdef RV64
    Reg#(Maybe#(Word)) readData <- mkReg(tagged Invalid);
    FIFO#(Word) dataReadQueue <- mkFIFO();
    
    rule dataRead;
        let response <- bram.portB.response.get();
        if (isValid(readData) == False) begin
            readData <= tagged Valid extend(response);
        end else begin
            let result = unJust(readData);
            result [63:32] = response;

            dataReadQueue.enq(result);
            readData <= tagged Invalid; 
        end
    endrule    

    Reg#(Maybe#(WriteData)) writeData <- mkReg(tagged Invalid);
    FIFO#(WriteData) dataWriteQueue <- mkFIFO();

    rule dataWrite;
        let writeValue = dataWriteQueue.first();
        if (isValid(writeData) == False) begin
            writeData <= tagged Valid writeValue;

            bram.portB.request.put(BRAMRequestBE {
                writeen: writeValue.byteEnable[3:0],
                responseOnWrite: False,
                address: writeValue.wordAddress[31:0],
                datain: writeValue.lower
            });
        end else begin
            bram.portB.request.put(BRAMRequestBE {
                writeen: writeValue.byteEnable[7:4],
                responseOnWrite: False,
                address: writeValue.wordAddress[31:0] + 1,
                datain: writeValue.upper
            });

            writeData <= tagged Invalid;
            dataWriteQueue.deq();
        end
    endrule
`endif

    interface InstructionMemoryServer instructionMemory;
        interface Get response;
            method ActionValue#(InstructionMemoryResponse) get;
                let response <- bram.portA.response.get();
                let requestAddress = requestAddressQueue.first();
                requestAddressQueue.deq();
                return InstructionMemoryResponse {
                    address: requestAddress,
                    data: response
                };
            endmethod
        endinterface

        interface Put request;
            method Action put(InstructionMemoryRequest request);
                let wordAddress = request.address >> 2;
                bram.portA.request.put(BRAMRequestBE {
                    writeen: 0,
                    responseOnWrite: ?,
                    address: wordAddress[31:0],
                    datain: ?
                });
                requestAddressQueue.enq(request.address);
            endmethod
        endinterface
    endinterface

    interface DataMemoryServer dataMemory;
        interface Get response;
            method ActionValue#(MemoryResponse#(XLEN)) get;
`ifdef RV32
                let response <- bram.portB.response.get();
                Word data = extend(response);
`else //  RV64
                let data = dataReadQueue.first();
                dataReadQueue.deq();
`endif
                return MemoryResponse {
                    data: data
                };
            endmethod
        endinterface

        interface Put request;
            method Action put(MemoryRequest#(XLEN, XLEN) request);
                let wordAddress = request.address >> 2;
`ifdef RV32
                bram.portB.request.put(BRAMRequestBE {
                    writeen: request.byteen[3:0],
                    responseOnWrite: False,
                    address: wordAddress,
                    datain: request.data[31: 0]
                });
`else // RV64
                dataWriteQueue.enq(WriteData {
                    lower: request.data[31:0],
                    upper: request.data[63:32],
                    wordAddress: wordAddress,
                    byteEnable: request.byteen
                });
`endif            
            endmethod
        endinterface
    endinterface
endmodule
