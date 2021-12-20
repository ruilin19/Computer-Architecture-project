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
//    input wire is_indelayslot_i,
//    input wire is_next_indelayslot_id_i,
//    output wire is_next_indelayslot_id_o,
    output wire stall_ex,//ex段暂停信号
    output wire [5:0]ex_aluop_o,
    output wire [4:0]ex_addr_o
);
    reg ex_stop;
    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus_rr;
    wire ex_to_iden;//ex传给下一条流水的ID端的使能信号
    wire [4:0] ex_to_iregaddr;//ex传给下一条流水的ID端的数据的地址
    wire [31:0] ex_to_idata;//ex传给下一条流水的ID端的数据
    wire ex_id_hlwe; //ex to id hl_we
    wire [1:0]ex_id_hlwaddr;//ex to id hl_waddr
    wire [63:0] ex_id_hlwdata;//ex to id hl_wdata
    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            ex_stop=1'b1;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
            ex_stop=1'b0;
        end
        else if(stall[2]==`Stop && stall[3]==`Stop) begin
            ex_stop=1'b1;
        end
    end
    assign id_to_ex_bus_rr=id_to_ex_bus_r;

    wire [31:0] ex_pc, inst;//指令地址以及指令
    wire [11:0] alu_op;//运算类型
    wire [2:0] sel_alu_src1;//操作数1来源
    wire [3:0] sel_alu_src2;//操作数2来源
    wire data_ram_en;
    wire [3:0] data_ram_wen;//访存信号
    wire rf_we;//读寄存器使能信号
    wire [4:0] rf_waddr;//寄存器的位置
    wire hl_we;//hl we
    wire [1:0]hl_waddr;// hl address
    wire sel_rf_res;//选择的结果
    wire [31:0] rf_rdata1, rf_rdata2;//从寄存器中读入的数据
    wire [63:0] hl_rdata;//hl data
//    wire [31:0] ex_save_inst;//要保存的指令
//    wire [31:0] pc_plus_8;
//    assign is_next_indelayslot_id_o=is_next_indelayslot_id_i;
//    assign pc_plus_8=ex_pc+32'h8;
    assign ex_aluop_o=inst[31:26];
    assign ex_addr_o =rf_waddr;
    assign {
        hl_rdata,       //225:162
        hl_waddr,       //161:160
        hl_we,          //159
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
        rf_rdata1,      // 63:32
        rf_rdata2       // 31:0
    } = ex_stop?id_to_ex_bus_rr:id_to_ex_bus_r;
    
    wire is_lsa;
    wire [2:0] lsa_sa;
    assign is_lsa= (inst[31:26]==6'b01_1100)&&(inst[5:0]==6'b11_0111);
    assign lsa_sa = {1'b0,inst[7:6]}+3'b001;
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};//对立即数做有符号扩展
    assign imm_zero_extend = {16'b0, inst[15:0]};//对立即数做无符号扩展
    assign sa_zero_extend = {27'b0,inst[10:6]};//对sa做无符号扩展
    //判断是不是mfhi或者mflo
    wire mf_hi;
    wire mf_lo;
    assign mf_hi = (inst[31:16] == 16'b0)&&(inst[10:6] == 5'b0)&&(inst[5:0] == 6'b01_0000);
    assign mf_lo = (inst[31:16] == 16'b0)&&(inst[10:6] == 5'b0)&&(inst[5:0] == 6'b01_0010);
    
    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;
    
    assign alu_src1 =sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : 
                      is_lsa          ?(rf_rdata1<<lsa_sa):rf_rdata1;
    
    assign alu_src2 =sel_alu_src2[0] ? rf_rdata2:
                      sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend :32'b0 ;
    //跟据sel的类型选择合适的操作数来源
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );
//    assign ex_save_inst=(alu_op==12'd0)?pc_plus_8:32'd0;
//    assign ex_result =rf_we&(rf_waddr==32'd31)?ex_save_inst: alu_result;//ALU计算结果
//    assign ex_result = hl_we?hl_rdata:alu_result;
    assign ex_result = mf_lo ? hl_rdata[63:32]:
                        mf_hi ? hl_rdata[31:0]:alu_result;
    assign data_sram_en=data_ram_en;
    assign data_sram_wen=(data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b00)?4'b0001:
                          (data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b01)?4'b0010:
                          (data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b10)?4'b0100:
                          (data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b11)?4'b1000:
                          (data_ram_wen==4'b0011)&&(data_sram_addr[1:0]==2'b00)?4'b0011:
                          (data_ram_wen==4'b0011)&&(data_sram_addr[1:0]==2'b10)?4'b1100:
                          (data_ram_wen==4'b1111)?4'b1111:4'b0000;
    assign data_sram_addr=data_ram_en?ex_result:32'd0;
    assign data_sram_wdata=(data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b00)?{24'b0,rf_rdata2[7:0]}:
                            (data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b01)?{16'b0,rf_rdata2[7:0],8'b0}:
                            (data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b10)?{8'b0,rf_rdata2[7:0],16'b0}:
                            (data_ram_wen==4'b0001)&&(data_sram_addr[1:0]==2'b11)?{rf_rdata2[7:0],24'b0}:
                            (data_ram_wen==4'b0011)&&(data_sram_addr[1:0]==2'b00)?{16'b0,rf_rdata2[15:0]}:
                            (data_ram_wen==4'b0011)&&(data_sram_addr[1:0]==2'b10)?{rf_rdata2[15:0],16'b0}:
                            (data_ram_wen==4'b1111)?rf_rdata2:32'd0;
    wire [5:0] ld_type_o;
    wire [1:0] addr_ram_o;
    assign ld_type_o=inst[31:26];
    assign addr_ram_o=data_sram_addr[1:0];
    wire [63:0] muldiv_mt_hl;
    assign ex_to_mem_bus = {
        addr_ram_o,           //150:149
        muldiv_mt_hl,       //148:85
        hl_waddr,       //84:83
        hl_we,          //82
        ld_type_o,      //81:76
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    assign stall_ex = stallreq_for_div|stallreq_for_mul;
//    乘法部分
//    wire [63:0] mul_result_p;
//    wire inst_mult_p;
//    wire inst_multu_p;
//    wire mul_signed_p; // 有符号乘法标记
//    assign inst_mult_p = (inst[31:26]==6'b0)&(inst[15:6]==10'b0)&(inst[5:0]==6'b01_1000);
//    assign inst_multu_p = (inst[31:26]==6'b0)&(inst[15:6]==10'b0)&(inst[5:0]==6'b01_1001);
//    assign mul_signed_p = inst_mult_p;
    
//    mul u_mul(
//    	.clk        (clk            ),
//        .resetn     (~rst           ),
//        .mul_signed (mul_signed_p ),
//        .ina        (alu_src1       ), // 乘法源操作数1
//        .inb        (alu_src2       ), // 乘法源操作数2
//        .result     (mul_result_p     ) // 乘法结果 64bit
//    );
    //乘法部分_自制乘法器
    wire [63:0] mul_result;
    wire inst_mult,inst_multu;
    wire mul_ready_i;
    reg stallreq_for_mul;
    reg [31:0] mul_opdata1_o;
    reg [31:0] mul_opdata2_o;
    reg mul_start_o;
    reg signed_mul_o;
    assign inst_mult = (inst[31:26]==6'b0)&(inst[15:6]==10'b0)&(inst[5:0]==6'b01_1000);
    assign inst_multu = (inst[31:26]==6'b0)&(inst[15:6]==10'b0)&(inst[5:0]==6'b01_1001);
    
    
    mul_self u_mul_self(
        .rst          (rst              ),
        .clk          (clk              ),
        .signed_mul_i (signed_mul_o     ),
        .opdata1_i    (mul_opdata1_o    ),
        .opdata2_i    (mul_opdata2_o    ),
        .start_i      (mul_start_o      ),
        .annul_i      (1'b0             ),
        .result_o     (mul_result       ), // 除法结果 64bit
        .ready_o      (mul_ready_i      )
    );
    
    always @ (*) begin
        if (rst) begin
            stallreq_for_mul = `NoStop;
            mul_opdata1_o = `ZeroWord;
            mul_opdata2_o = `ZeroWord;
            mul_start_o = `MulStop;
            signed_mul_o = 1'b0;
        end
        else begin
            stallreq_for_mul = `NoStop;
            mul_opdata1_o = `ZeroWord;
            mul_opdata2_o = `ZeroWord;
            mul_start_o = `MulStop;
            signed_mul_o = 1'b0;
            case ({inst_mult,inst_multu})
                2'b10:begin
                    if (mul_ready_i == `MulResultNotReady) begin
                        mul_opdata1_o = alu_src1;
                        mul_opdata2_o = alu_src2;
                        mul_start_o = `MulStart;
                        signed_mul_o = 1'b1;
                        stallreq_for_mul = `Stop;
                    end
                    else if (mul_ready_i == `MulResultReady) begin
                        mul_opdata1_o = alu_src1;
                        mul_opdata2_o = alu_src2;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b1;
                        stallreq_for_mul = `NoStop;
                    end
                    else begin
                        mul_opdata1_o = `ZeroWord;
                        mul_opdata2_o = `ZeroWord;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                end
                2'b01:begin
                    if (mul_ready_i == `MulResultNotReady) begin
                        mul_opdata1_o = alu_src1;
                        mul_opdata2_o = alu_src2;
                        mul_start_o = `MulStart;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `Stop;
                    end
                    else if (mul_ready_i == `MulResultReady) begin
                        mul_opdata1_o = alu_src1;
                        mul_opdata2_o = alu_src2;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                    else begin
                        mul_opdata1_o = `ZeroWord;
                        mul_opdata2_o = `ZeroWord;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end
    
    
    
    
    
    //除法部分
    wire [63:0] div_result;
    wire inst_div,inst_divu;
    wire div_ready_i;
    reg stallreq_for_div;
    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;
//    assign stall_ex = stallreq_for_div;
    assign inst_div=(inst[31:26]==6'b0)&(inst[15:6]==10'b0)&(inst[5:0]==6'b01_1010);
    assign inst_divu =(inst[31:26]==6'b0)&(inst[15:6]==10'b0)&(inst[5:0]==6'b01_1011);
    div u_div(
    	.rst          (rst              ),
        .clk          (clk              ),
        .signed_div_i (signed_div_o     ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0             ),
        .result_o     (div_result       ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );

    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end
    
    assign muldiv_mt_hl=(inst_mult|inst_multu)?{mul_result[31:0],mul_result[63:32]}:
                         (inst_div|inst_divu)?{div_result[31:0],div_result[63:32]}:
                         (hl_we&hl_waddr[1]==1'b1)?{ex_result,32'b0}:
                         (hl_we&hl_waddr[1]==1'b0)?{32'b0,ex_result}:hl_rdata;
    assign ex_to_iden = rf_we;
    assign ex_to_iregaddr = rf_waddr;
    assign ex_to_idata = ex_result;
    assign ex_id_hlwe = hl_we;
    assign ex_id_hlwaddr = hl_waddr;
    assign ex_id_hlwdata = muldiv_mt_hl;
    assign ex_to_id_bus={
        ex_id_hlwdata, //104:41
        ex_id_hlwaddr,//40:39
        ex_id_hlwe,//38
        ex_to_iden,//37
        ex_to_iregaddr,//36:32
        ex_to_idata//31:0
};
endmodule