`include "lib/defines.vh"
module mycpu_core(
    input wire clk,
    input wire rst,
    input wire [5:0] int,

    output wire inst_sram_en,//输出指令使能信号
    output wire [3:0] inst_sram_wen,//写入NPC使能信号
    output wire [31:0] inst_sram_addr,//NPC的地址
    output wire [31:0] inst_sram_wdata,//NPC值
    input wire [31:0] inst_sram_rdata,//输入指令

    output wire data_sram_en,//输出数据使能信号
    output wire [3:0] data_sram_wen,//写入数据使能信息
    output wire [31:0] data_sram_addr,//数据地址
    output wire [31:0] data_sram_wdata,//数据值
    input wire [31:0] data_sram_rdata,//输入数据

    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus;
    wire [`EX_TO_ID_WD-1:0] ex_to_id_bus;//旁路1 EX TO ID
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus;
    wire [`MEM_TO_ID_WD-1:0] mem_to_id_bus;//旁路2 MEM TO ID
    wire [`BR_WD-1:0] br_bus; 
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus;
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;
    wire [`StallBus-1:0] stall;
    wire is_indelayslot_id_in;
    wire is_indelayslot_id_out;
    wire next_is_indelayslot;
    wire id_stall;//id段暂停信号
    wire ex_stall;//ex段暂停信号
    wire [5:0] ex_aluop;
    wire [4:0] ex_raddr;
    IF u_IF(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .br_bus          (br_bus          ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_en    (inst_sram_en    ),
        .inst_sram_wen   (inst_sram_wen   ),
        .inst_sram_addr  (inst_sram_addr  ),
        .inst_sram_wdata (inst_sram_wdata )
    );
    

    ID u_ID(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .stallreq        (stallreq        ),
        .if_to_id_bus    (if_to_id_bus    ),
        .ex_to_id_bus    (ex_to_id_bus    ),
        .mem_to_id_bus   (mem_to_id_bus   ),
        .inst_sram_rdata (inst_sram_rdata ),
        .wb_to_rf_bus    (wb_to_rf_bus    ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .br_bus          (br_bus          ),
        .is_indelayslot_o (is_indelayslot_id_out),//告诉exe这条指令位于延迟槽
        .next_is_indelayslot(next_is_indelayslot),//告诉exe下一条指令位于延迟槽
        .is_indelayslot_i (is_indelayslot_id_in),//exe回传给id下一条条指令位于延迟槽
        .stallreq_id(id_stall),
        .ex_aluop (ex_aluop),
        .ex_addr  (ex_raddr)
    );
    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .ex_to_id_bus    (ex_to_id_bus    ),//旁路1 EX TO ID
        .data_sram_en    (data_sram_en    ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata ),
        .is_indelayslot_i (is_indelayslot_id_out),//告诉exe这条指令是否位于延迟槽
        .is_next_indelayslot_id_i (next_is_indelayslot),//告诉exe下一条指令位于延迟槽
        .is_next_indelayslot_id_o (is_indelayslot_id_in),//回传给id下一条指令位于延迟槽
        .stall_ex                   (ex_stall),
        .ex_aluop_o                 (ex_aluop),
        .ex_addr_o                  (ex_raddr)
    );

    MEM u_MEM(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_rdata (data_sram_rdata ),
        .mem_to_wb_bus   (mem_to_wb_bus   ),
        .mem_to_id_bus   (mem_to_id_bus   )//旁路2 MEM TO ID
    );
    
    WB u_WB(
    	.clk               (clk               ),
        .rst               (rst               ),
        .stall             (stall             ),
        .mem_to_wb_bus     (mem_to_wb_bus     ),
        .wb_to_rf_bus      (wb_to_rf_bus      ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    CTRL u_CTRL(
    	.rst   (rst   ),
        .stall (stall ),
        .stall_for_id(id_stall),
        .stall_for_ex(ex_stall)
    );
    
endmodule