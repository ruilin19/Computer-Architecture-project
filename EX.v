`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    output wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,
    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input wire is_indelayslot_i,
    input wire is_next_indelayslot_id_i,
    output wire is_next_indelayslot_id_o,
    output wire stall_ex,//ex段暂停信号
    output wire [5:0]ex_aluop_o,
    output wire [4:0]ex_addr_o
);
    
    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;
    wire ex_to_iden;//ex传给下一条流水的ID端的使能信号
    wire [4:0] ex_to_iregaddr;//ex传给下一条流水的ID端的数据的地址
    wire [31:0] ex_to_idata;//ex传给下一条流水的ID端的数据
    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;//指令地址以及指令
    wire [11:0] alu_op;//运算类型
    wire [2:0] sel_alu_src1;//操作数1来源
    wire [3:0] sel_alu_src2;//操作数2来源
    wire data_ram_en;
    wire [3:0] data_ram_wen;//访存信号
    wire rf_we;//读寄存器使能信号
    wire [4:0] rf_waddr;//寄存器的位置
    wire sel_rf_res;//选择的结果
    wire [31:0] rf_rdata1, rf_rdata2;//从寄存器中读入的数据
    wire [31:0] ex_save_inst;//要保存的指令
    wire [31:0] pc_plus_8;
    assign is_next_indelayslot_id_o=is_next_indelayslot_id_i;
    assign pc_plus_8=ex_pc+32'h8;
    assign ex_aluop_o=inst[31:26];
    assign ex_addr_o =rf_waddr;
    assign {
        ex_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};//对立即数做有符号扩展
    assign imm_zero_extend = {16'b0, inst[15:0]};//对立即数做无符号扩展
    assign sa_zero_extend = {27'b0,inst[10:6]};//对sa做无符号扩展

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;
    
    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    //跟据sel的类型选择合适的操作数来源
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );
    assign ex_save_inst=(alu_op==12'd0)?pc_plus_8:32'd0;
    assign ex_result =rf_we&(rf_waddr==32'd31)?ex_save_inst: alu_result;//ALU计算结果
    assign data_sram_en=data_ram_en;
    assign data_sram_wen=data_ram_wen;
    assign data_sram_addr=data_ram_en?ex_result:32'd0;
    assign data_sram_wdata=(data_ram_wen==4'b0001)?rf_rdata2:
          (data_ram_wen==4'b0011)?rf_rdata2:
          (data_ram_wen==4'b1111)?rf_rdata2:32'd0;
    wire [5:0] ld_type_o;
    assign ld_type_o=inst[31:26];
    assign ex_to_mem_bus = {
        ld_type_o,      //81:76
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    assign ex_to_iden=rf_we;
    assign ex_to_iregaddr=rf_waddr;
    assign ex_to_idata=ex_result;
    assign ex_to_id_bus={
        ex_to_iden,//37
        ex_to_iregaddr,//36:32
        ex_to_idata//31:0
    };
endmodule