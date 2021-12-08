`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,  
    output wire stallreq,
    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,
    input wire [31:0] inst_sram_rdata,
    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,
    input wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,
    input wire [`MEM_TO_ID_WD-1:0] mem_to_id_bus,
    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    output wire [`BR_WD-1:0] br_bus, //分支bus
//    output wire is_indelayslot_o,//输出给ex 该指令是否位于延迟槽
//    output wire next_is_indelayslot,//下一条指令是否位于延迟槽
//    input  wire is_indelayslot_i,//id的指令是否位于延迟槽
    output wire stallreq_id,//来自ID段的暂停信号
    input wire [5:0] ex_aluop,//ex段正在执行的操作
    input wire [4:0] ex_addr//ex段要访问的寄存器
);
    wire ex_inst_isload;//ex段是否load
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;//if to id 的数据
    wire [31:0] inst;//指令
    wire [31:0] id_pc;//id段的指令地址
    wire ce;//使能信号
    
    //we ex mem 定义线
    wire wb_rf_we;//WB段回写的信号
    wire [4:0] wb_rf_waddr;//WB段回写的数据地址
    wire [31:0] wb_rf_wdata;//WB段回写的数据
    wire ex_rf_we;//ex段回写使能信号
    wire [4:0] ex_rf_waddr;//ex段回写寄存器
    wire [31:0] ex_rf_wdata;//ex段回写数据
    wire mem_rf_we;//ex段回写使能信号
    wire [4:0] mem_rf_waddr;//mem段回写寄存器
    wire [31:0] mem_rf_wdata;//mem段回写数据
    
    //reg线
    wire [31:0] data1;
    wire [31:0] data2;
    reg id_stop;
    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            id_stop <=1'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            id_stop <=1'b1;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
            id_stop <=1'b0;
        end
        else begin
            id_stop <=1'b1;
            end
    end
    
    
    assign ex_inst_isload =(ex_aluop==6'b10_0000)|
                            (ex_aluop==6'b10_0100)|
                            (ex_aluop==6'b10_0001)|
                            (ex_aluop==6'b10_0101)|
                            (ex_aluop==6'b10_0011);
    assign stallreq_id=(ex_inst_isload==1'b0)?1'b0:
                        (ex_addr==rs|ex_addr==rt)?1'b1:1'b0;
    assign inst=id_stop?inst:inst_sram_rdata;//PC对应的指令码
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    //wb ex mem回写
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;
    assign {
        ex_rf_we,
        ex_rf_waddr,
        ex_rf_wdata
    }=ex_to_id_bus;
    assign {
        mem_rf_we,
        mem_rf_waddr,
        mem_rf_wdata
    }=mem_to_id_bus;
    
    
    
    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;// 独热码

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );
    assign data1=(ex_rf_we==1'b1)&&(ex_rf_waddr==rs)?ex_rf_wdata:
                (mem_rf_we==1'b1)&&(mem_rf_waddr==rs)?mem_rf_wdata:
                (wb_rf_we==1'b1)&&(wb_rf_waddr==rs)?wb_rf_wdata:rdata1;
    assign data2=(ex_rf_we==1'b1)&&(ex_rf_waddr==rt)?ex_rf_wdata:
                 (mem_rf_we==1'b1)&&(mem_rf_waddr==rt)?mem_rf_wdata:
                 (wb_rf_we==1'b1)&&(wb_rf_waddr==rt)?wb_rf_wdata:rdata2;


    assign opcode = inst[31:26];//取操作码
    assign rs = inst[25:21];//rs对应寄存器
    assign rt = inst[20:16];//rt对应寄存器
    assign rd = inst[15:11];//rd对应寄存器
    assign sa = inst[10:6];//R类指令中的第6到10位
    assign func = inst[5:0];//R类指令func段
    assign imm = inst[15:0];//I类指令立即数段
    assign instr_index = inst[25:0];//J类指令地址段
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];//运算类型

    wire inst_ori, inst_lui, inst_addiu;
    wire inst_sub,inst_slt,inst_sltu,inst_slti,inst_sltiu;
    wire inst_and,inst_nor,inst_or,inst_xor;
    wire inst_sll,inst_srl,inst_sra;
    wire inst_subu;
    wire inst_addu;
    wire inst_add;
    wire inst_addi;
    wire inst_andi;
    wire inst_xori;
    wire inst_sllv;
    wire inst_srav;
    wire inst_srlv;
    //load store
    wire inst_lb,inst_lbu,inst_lh,inst_lhu,inst_lw;
    wire inst_sb,inst_sh,inst_sw;
    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;
    //跳转指令
    wire inst_j,inst_jal,inst_jr,inst_jalr;
    //分支指令
    wire inst_beq,inst_bne,inst_bgez,inst_bgtz,inst_blez,inst_bltz,inst_bgezal,inst_bltzal;
    //空指令
//    wire inst_nop;
    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )//运算的独热编码，只有一位为1表明该条指令的运算类型为这一种
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )//func的独热编码，只有一位为1表明该条指令的运算类型为这一种
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )//rs对应寄存器的独热编码，
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )//rt对应寄存器的独热编码，
    );
    decoder_5_32 u2_decoder_5_32(
    	.in  (rd  ),
        .out (rd_d )//rt对应寄存器的独热编码，
    );
    decoder_5_32 u3_decoder_5_32(
    	.in  (sa  ),
        .out (sa_d )//rt对应寄存器的独热编码，
    );

    
    assign inst_ori     = op_d[6'b00_1101];//6'b00_1101表示索引，取独热码的这一位；
    //同时00_1101为ori运算的指令码 如果该独热码是ori的独热码，那么会取出1 否则 取出0
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    //新的运算类型对应的使能信号
    assign inst_sub     = op_d[6'b00_0000]&func_d[6'b10_0010];
    assign inst_subu    = op_d[6'b00_0000]&func_d[6'b10_0011];
    assign inst_slt     = op_d[6'b00_0000]&func_d[6'b10_1010];
    assign inst_sltu    = op_d[6'b00_0000]&func_d[6'b10_1011];
    assign inst_slti    = op_d[6'b00_1010];
    assign inst_sltiu   = op_d[6'b00_1011];
    assign inst_and     = op_d[6'b00_0000]&func_d[6'b10_0100];
    assign inst_nor     = op_d[6'b00_0000]&func_d[6'b10_0111];
    assign inst_or      = op_d[6'b00_0000]&func_d[6'b10_0101];
    assign inst_xor     = op_d[6'b00_0000]&func_d[6'b10_0110];
    assign inst_sll     = op_d[6'b00_0000]&func_d[6'b00_0000];
    assign inst_srl     = op_d[6'b00_0000]&func_d[6'b00_0010];
    assign inst_sra     = op_d[6'b00_0000]&func_d[6'b00_0011];
    assign inst_addu    = op_d[6'b00_0000]&func_d[6'b10_0001];
    assign inst_add     = op_d[6'b00_0000]&func_d[6'b10_0000];
    assign inst_addi    = op_d[6'b00_1000];
    assign inst_andi    = op_d[6'b00_1100];
    assign inst_xori    = op_d[6'b00_1110];
    assign inst_sllv    = op_d[6'b00_0000]&func_d[6'b00_0100];
    assign inst_srav    = op_d[6'b00_0000]&func_d[6'b00_0111];
    assign inst_srlv    = op_d[6'b00_0000]&func_d[6'b00_0110];
    //load store指令
    assign inst_lb     =op_d[6'b10_0000];
    assign inst_lbu    =op_d[6'b10_0100];
    assign inst_lh     =op_d[6'b10_0001];
    assign inst_lhu    =op_d[6'b10_0101];
    assign inst_lw     =op_d[6'b10_0011];
    assign inst_sb     =op_d[6'b10_1000];
    assign inst_sh     =op_d[6'b10_1001];
    assign inst_sw     =op_d[6'b10_1011]; 
    //跳转指令
    assign inst_jr      =op_d[6'b00_0000]&&func_d[6'b00_1000];
    assign inst_jalr    =op_d[6'b00_0000]&&func_d[6'b00_1001];
    assign inst_jal     =op_d[6'b00_0011];
    assign inst_j       =op_d[6'b00_0010];
    //分支指令
    assign inst_beq     = op_d[6'b00_0100];//==
    assign inst_bne     = op_d[6'b00_0101];//！=
    assign inst_bgez    = op_d[6'b00_0001]&rt_d[5'b00001];//>=0
    assign inst_bgtz    = op_d[6'b00_0111];//>0
    assign inst_blez    = op_d[6'b00_0110];//<=0
    assign inst_bltz    = op_d[6'b00_0001]&rt_d[5'b00000];//<0
    assign inst_bgezal  = op_d[6'b00_0001]&rt_d[5'b10001];//>=0
    assign inst_bltzal  = op_d[6'b00_0001]&rt_d[5'b10000];//<0
    
    // rs to reg1
    assign sel_alu_src1[0] = inst_ori|inst_addiu|inst_add|inst_addu|inst_addi|inst_sllv|inst_srav|inst_srlv
                             |inst_sub|inst_subu|inst_slt|inst_sltu|inst_slti|inst_sltiu
                             |inst_and|inst_andi|inst_nor|inst_or|inst_xor|inst_xori
                             |inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw;//rs的值作src1

    // pc to reg1
    assign sel_alu_src1[1] = 1'b0|inst_bgezal|inst_bltzal|inst_jal|inst_jalr;//src1为pc值

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = 1'b0|inst_sll|inst_srl|inst_sra;//无符号扩展数做src1

    // rt to reg2
    assign sel_alu_src2[0] = 1'b0|inst_sub|inst_subu|inst_slt|inst_sltu|inst_and|inst_srav|inst_srlv
                             |inst_nor|inst_or|inst_xor|inst_sll|inst_srl|inst_sra|inst_addu|inst_add|inst_sllv;//rt作src2
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw|inst_slti|inst_sltiu|inst_addi;//有符号扩展数作src2

    // 32'b8 to reg2
    assign sel_alu_src2[2] = 1'b0|inst_bgezal|inst_bltzal|inst_jal|inst_jalr;//32位的整数8作为src2

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori|inst_andi|inst_xori;//立即数的无符号扩展作src2



    assign op_add = inst_addiu|inst_addu|inst_add|inst_addi
                              |inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw
                              |inst_bgezal|inst_bltzal|inst_jal|inst_jalr;
    assign op_sub = inst_sub |inst_subu;
    assign op_slt = inst_slt|inst_slti;
    assign op_sltu = inst_sltu|inst_sltiu;
    assign op_and = inst_and|inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori|inst_or;
    assign op_xor = inst_xor|inst_xori;
    assign op_sll = inst_sll|inst_sllv;
    assign op_srl = inst_srl|inst_srlv;
    assign op_sra = inst_sra|inst_srav;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};//op独热码


    //!!!!!!!!在这添加load指令
    // load and store enable
    assign data_ram_en = inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh|inst_sw;

//    // write enable
    assign data_ram_wen = inst_sb?4'b0001:
                          inst_sh?4'b0011:
                          inst_sw?4'b1111:
                          inst_lb|inst_lbu|inst_lh|inst_lhu|inst_lw?4'b0000:4'b1110;
    //一个字节 还是 半字 还是字
    
    // regfile sotre enable
    assign rf_we = inst_ori |inst_lui|inst_sub|inst_subu|inst_srav|inst_srlv
                            |inst_and|inst_andi|inst_nor|inst_or|inst_xor|inst_xori
                            |inst_add|inst_addi|inst_addiu|inst_addu|inst_sllv
                            |inst_slt|inst_slti|inst_sltiu|inst_sltu|inst_sll|inst_srl|inst_sra
                            |inst_bgezal|inst_bltzal|inst_jal|inst_jalr
                            |inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu;



    // store in [rd]
    assign sel_rf_dst[0] = 1'b0|inst_sub|inst_subu|inst_addu|inst_and|inst_sllv|inst_srav|inst_srlv
                               |inst_nor|inst_or|inst_xor|inst_slt|inst_sltu|inst_sll|inst_srl|inst_sra|inst_add|inst_jalr;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori|inst_lui|inst_addiu|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_slti|inst_sltiu|inst_sltiu|inst_addi|inst_andi|inst_xori;
    // store in [31]
    assign sel_rf_dst[2] = 1'b0|inst_bgezal|inst_bltzal|inst_jal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;//选择结果存储的寄存器

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = 1'b0|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu; //选择存储寄存器中的值的来源
 
    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        data1,         // 63:32
        data2          // 31:0
    };


    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_neq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;
    
    assign rs_eq_rt =   (data1 == data2);
    assign rs_neq_rt=   (data1!=data2);
    assign rs_ge_z=     (data1 == 32'b0)||(~data1[31]);
    assign rs_gt_z=     (~data1[31])&&(data1 != 32'b0);
    assign rs_le_z=     (data1 == 32'b0)||(data1[31]);
    assign rs_lt_z=     (data1[31]);
    
    //跳转指令
    assign br_e = inst_j|inst_jr|inst_jal|inst_jalr
                        |(inst_beq&rs_eq_rt)|(inst_bne&rs_neq_rt)
                        |(inst_bgez&rs_ge_z)|(inst_bgtz&rs_gt_z)
                        |(inst_blez&rs_le_z)|(inst_bltz&rs_lt_z)
                        |(inst_bgezal&rs_ge_z)|(inst_bltzal&rs_lt_z);
    assign br_addr =(inst_j|inst_jal)?{pc_plus_4[31:28],instr_index,2'b0}:
                    ((inst_jr|inst_jalr)?data1:
                    (inst_beq|inst_bne|inst_bgez|inst_bgtz|inst_blez|inst_bltz|inst_bgezal|inst_bltzal)?(pc_plus_4 + {{14{offset[15]}},offset,2'b0}):32'b0 );
    //跳转分支，如果跳转br使能信号和br地址都会改变
//    assign next_is_indelayslot=1'b0|inst_jal|inst_jr|inst_jalr|inst_j|inst_bgtz|inst_blez|inst_bne|inst_bgez|inst_bgezal|inst_bltz|inst_bltzal;
//    assign is_indelayslot_o=is_indelayslot_i;
    assign br_bus = {
        br_e,
        br_addr
    };


endmodule