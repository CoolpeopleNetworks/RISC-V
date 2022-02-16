import PGTypes::*;

import Exception::*;
import ExecutionUnit::*;
import ExecutedInstruction::*;

import Assert::*;
import Printf::*;

typedef enum {
    INIT,
    STORE_REQUEST_TEST,
    COMPLETE
} State deriving(Bits, Eq, FShow);

typedef struct {
    Bool shouldSucceed;
    RVStoreOperator storeOperator;
    Word effectiveAddress;
    Word value;

    Maybe#(Exception) expectedException;
    Word expectedWordAddress;
    Bit#(TDiv#(XLEN, 8)) expectedByteEnable;
    Word expectedValue;
} StoreTestCase deriving(Bits, Eq, FShow);

(* synthesize *)
module mkMemoryAccessUnit_tb(Empty);
    Reg#(State) state <- mkReg(INIT);
    Reg#(Word) testNumber <- mkReg(0);

`ifdef RV64
    let storeTestCaseCount = 19;
`else // RV32
    let storeTestCaseCount = 8;
`endif
    StoreTestCase testCases[storeTestCaseCount] = {
        //
        // Single byte store
        //
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4000,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b1,
            expectedValue:          'hff
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4001,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b10,
            expectedValue:          'hff00
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4002,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b100,
            expectedValue:          'hff0000
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4003,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b1000,
            expectedValue:          'hff000000
        },
`ifdef RV64
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4004,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b10000,
            expectedValue:          'hff00000000
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4005,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b100000,
            expectedValue:          'hff0000000000
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4006,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b1000000,
            expectedValue:          'hff000000000000
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4007,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b10000000,
            expectedValue:          'hff00000000000000
        },
`endif

        //
        // Half-word store
        //
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4000,
            value:                  'hff44,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b0011,
            expectedValue:          'h0000_ff44
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4002,
            value:                  'h0000_ff44,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b1100,
            expectedValue:          'hff44_0000
        },
`ifdef RV64
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4004,
            value:                  'hff44,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b110000,
            expectedValue:          'hff44_0000_0000
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4006,
            value:                  'hff44,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b11000000,
            expectedValue:          'hff44_0000_0000_0000
        },
`endif
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4001,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedWordAddress:    ?,
            expectedByteEnable:     ?,
            expectedValue:          ?
        },
`ifdef RV64
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4003,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedWordAddress:    ?,
            expectedByteEnable:     ?,
            expectedValue:          ?
        },
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4005,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedWordAddress:    ?,
            expectedByteEnable:     ?,
            expectedValue:          ?
        },
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4007,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedWordAddress:    ?,
            expectedByteEnable:     ?,
            expectedValue:          ?
        },
`endif
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SW),
            effectiveAddress:       'h4000,
            value:                  'hff44_AA11,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b1111,
            expectedValue:          'hff44_AA11
        }
`ifdef RV64
        ,
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SW),
            effectiveAddress:       'h4004,
            value:                  'hff44_AA11,

            expectedException:      tagged Invalid,
            expectedWordAddress:    'h4000,
            expectedByteEnable:     'b1111_0000,
            expectedValue:          'hff44_AA11_0000_0000
        },
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SW),
            effectiveAddress:       'h4002,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedWordAddress:    ?,
            expectedByteEnable:     ?,
            expectedValue:          ?
        }
`endif
    };

    rule init(state == INIT);
        state <= STORE_REQUEST_TEST;
    endrule

    rule store_request_test(state == STORE_REQUEST_TEST);
        let testCase = testCases[testNumber];

        let result = getStoreRequest(
            testCase.storeOperator, 
            testCase.effectiveAddress, 
            testCase.value);

        dynamicAssert(isSuccess(result) == testCase.shouldSucceed, "Request success should be what's expected");
        if (result matches tagged Success .storeRequest) begin
            dynamicAssert(storeRequest.wordAddress == testCase.expectedWordAddress, "Request word address incorrect.");
            dynamicAssert(storeRequest.byteEnable == testCase.expectedByteEnable, "Byte enable incorrect.");
            dynamicAssert(storeRequest.value == testCase.expectedValue, "Value incorrect.");
        end else begin
            dynamicAssert(result.Error == unJust(testCase.expectedException), "Incorrect exception returned");
        end

        if (testNumber == storeTestCaseCount - 1) begin
            state <= COMPLETE;
        end

        testNumber <= testNumber + 1;
    endrule

    rule complete(state == COMPLETE);
        $display("    PASS");
        $finish();
    endrule
endmodule
