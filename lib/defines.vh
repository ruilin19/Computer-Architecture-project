`define IF_TO_ID_WD 33
`define ID_TO_EX_WD 226
//`define EX_TO_MEM_WD 116
`define EX_TO_MEM_WD 151
//`define EX_TO_ID_WD 72//
`define EX_TO_ID_WD 105//
//`define MEM_TO_ID_WD 72//
`define MEM_TO_ID_WD 105
//`define MEM_TO_WB_WD 104
`define MEM_TO_WB_WD 137
`define BR_WD 33
`define DATA_SRAM_WD 69
`define WB_TO_RF_WD 137
`define StallBus 6
`define NoStop 1'b0
`define Stop 1'b1
`define ZeroWord 32'b0

//除法div
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0
// 2021-11-29 add
//自制乘法
`define MulFree 2'b00
`define MulByZero 2'b01
`define MulOn 2'b10
`define MulEnd 2'b11
`define MulResultReady 1'b1
`define MulResultNotReady 1'b0
`define MulStart 1'b1
`define MulStop 1'b0
