`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    output wire [`MEM_TO_ID_WD-1:0] mem_to_id_bus
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;
    wire mem_to_iden;//mem段给隔一段的id传的使能信号
    wire [4:0] mem_to_idregaddr;//mem段给隔一段的id传的寄存器地址
    wire [31:0] mem_to_idata;//mem段给隔一段的id传的数据
    wire mem_id_hlwe;//mem to id hl_we
    wire [1:0]mem_id_hlwaddr;//mem to id hl_waddr
    wire [63:0] mem_id_hlwdata; //mem to id hl_wdata
    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    wire [31:0] mem_pc;//mem段对应的PC
    wire data_ram_en;//访存使能信号
    wire [3:0] data_ram_wen;//写内存使能信号
    wire sel_rf_res;//选择寄存器
    wire rf_we;//寄存器使能信号
    wire [4:0] rf_waddr;//回写的地址
    wire [31:0] rf_wdata;//回写的数据
    wire hl_we;//hl we
    wire [1:0]hl_waddr;//hl address
    wire [63:0] hl_rdata;//hl data
    wire [31:0] ex_result;//ALU的结果
    wire [31:0] mem_result;//mem段的运算结果
    wire [5:0] ld_type_i;
    wire [1:0] addr_ram_i;
    assign {
        addr_ram_i,//150:149
        hl_rdata, //148:85
        hl_waddr, //84:83
        hl_we,  //82
        ld_type_i,//81:76
        mem_pc, // 75:44
        data_ram_en, // 43
        data_ram_wen, // 42:39
        sel_rf_res, // 38
        rf_we, // 37
        rf_waddr, // 36:32
        ex_result // 31:0
    } =  ex_to_mem_bus_r;
    

    assign mem_result=(ld_type_i==6'b10_0000)&&(addr_ram_i==2'b00)?{{24{data_sram_rdata[7]}},data_sram_rdata[7:0]}:
                       (ld_type_i==6'b10_0000)&&(addr_ram_i==2'b01)?{{24{data_sram_rdata[15]}},data_sram_rdata[15:8]}:
                       (ld_type_i==6'b10_0000)&&(addr_ram_i==2'b10)?{{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}:
                       (ld_type_i==6'b10_0000)&&(addr_ram_i==2'b11)?{{24{data_sram_rdata[31]}},data_sram_rdata[31:24]}:
                       (ld_type_i==6'b10_0100)&&(addr_ram_i==2'b00)?{24'b0,data_sram_rdata[7:0]}:
                       (ld_type_i==6'b10_0100)&&(addr_ram_i==2'b01)?{24'b0,data_sram_rdata[15:8]}:
                       (ld_type_i==6'b10_0100)&&(addr_ram_i==2'b10)?{24'b0,data_sram_rdata[23:16]}:
                       (ld_type_i==6'b10_0100)&&(addr_ram_i==2'b11)?{24'b0,data_sram_rdata[31:24]}:
                       (ld_type_i==6'b10_0001)&&(addr_ram_i==2'b00)?{{16{data_sram_rdata[15]}},data_sram_rdata[15:0]}:
                       (ld_type_i==6'b10_0001)&&(addr_ram_i==2'b10)?{{16{data_sram_rdata[31]}},data_sram_rdata[31:16]}:
                       (ld_type_i==6'b10_0101)&&(addr_ram_i==2'b00)?{16'b0,data_sram_rdata[15:0]}:
                       (ld_type_i==6'b10_0101)&&(addr_ram_i==2'b10)?{16'b0,data_sram_rdata[31:16]}:
                       (ld_type_i==6'b10_0011)?data_sram_rdata[31:0]:32'b0;
    assign rf_wdata = sel_rf_res ? mem_result : ex_result;//应该是负责处理三条指令数据相关时，什么时候去ex的值什么时候取mem的值
    //因为ex的值是第二条流水线的结果 mem是第一条流水线ex的结果在该周期存到mem中了
    assign mem_to_wb_bus = {
        hl_rdata, //136:73
        hl_waddr, //72:71
        hl_we,   //70
        mem_pc, // 69:38
        rf_we, // 37
        rf_waddr, // 36:32
        rf_wdata // 31:0
    };
    assign mem_to_iden=rf_we;
    assign mem_to_idregaddr=rf_waddr;
    assign mem_to_idata=rf_wdata;
    assign mem_id_hlwe=hl_we;
    assign mem_id_hlwaddr=hl_waddr;
    assign mem_id_hlwdata=hl_rdata;
    assign mem_to_id_bus={
      mem_id_hlwdata, //104:41
      mem_id_hlwaddr, //40:39
      mem_id_hlwe, //38 
      mem_to_iden,//37
      mem_to_idregaddr,//36:32
      mem_to_idata//31:0
    };

endmodule