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
    wire mem_to_iden;//mem�θ���һ�ε�id����ʹ���ź�
    wire [4:0] mem_to_idregaddr;//mem�θ���һ�ε�id���ļĴ�����ַ
    wire [31:0] mem_to_idata;//mem�θ���һ�ε�id��������
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

    wire [31:0] mem_pc;//mem�ζ�Ӧ��PC
    wire data_ram_en;//�ô�ʹ���ź�
    wire [3:0] data_ram_wen;//д�ڴ�ʹ���ź�
    wire sel_rf_res;//ѡ��Ĵ���
    wire rf_we;//�Ĵ���ʹ���ź�
    wire [4:0] rf_waddr;//��д�ĵ�ַ
    wire [31:0] rf_wdata;//��д������
    wire [31:0] ex_result;//ALU�Ľ��
    wire [31:0] mem_result;//mem�ε�������
    wire [5:0] ld_type_i;
    assign {
    ld_type_i,//81:76
    mem_pc, // 75:44
    data_ram_en, // 43
    data_ram_wen, // 42:39
    sel_rf_res, // 38
    rf_we, // 37
    rf_waddr, // 36:32
    ex_result // 31:0
    } =  ex_to_mem_bus_r;
    

    assign mem_result=(ld_type_i==6'b10_0000)?{{24{data_sram_rdata[7:0]}},data_sram_rdata[7:0]}:
                      (ld_type_i==6'b10_0100)?{24'b0,data_sram_rdata[7:0]}:
                      (ld_type_i==6'b10_0001)?{{16{data_sram_rdata[15:0]}},data_sram_rdata[15:0]}:
                       (ld_type_i==6'b10_0101)?{16'b0,data_sram_rdata[15:0]}:
                       (ld_type_i==6'b10_0011)?data_sram_rdata[31:0]:32'b0;
    assign rf_wdata = sel_rf_res ? mem_result : ex_result;//Ӧ���Ǹ���������ָ���������ʱ��ʲôʱ��ȥex��ֵʲôʱ��ȡmem��ֵ
    //��Ϊex��ֵ�ǵڶ�����ˮ�ߵĽ�� mem�ǵ�һ����ˮ��ex�Ľ���ڸ����ڴ浽mem����
    assign mem_to_wb_bus = {
    mem_pc, // 69:38
    rf_we, // 37
    rf_waddr, // 36:32
    rf_wdata // 31:0
    };
    assign mem_to_iden=rf_we;
    assign mem_to_idregaddr=rf_waddr;
    assign mem_to_idata=rf_wdata;
    assign mem_to_id_bus={
      mem_to_iden,//37
      mem_to_idregaddr,//36:32
      mem_to_idata//31:0
    };

endmodule