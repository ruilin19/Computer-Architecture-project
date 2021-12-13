`include "defines.vh"
module regfile(
    input wire clk,
    input wire [4:0] raddr1,
    output wire [31:0] rdata1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata2,
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata,
    //HiLo¼Ä´æÆ÷
    input wire p_raddr,//0->hi 1->lo
    output wire [31:0] hilo_o,//hilo output
    input wire p_we,//enable
    input wire [1:0] p_waddr,//0->hi 1-lo
    input wire [63:0] p_wdata//hi or lo
);
    reg [31:0] reg_array [31:0];//regfile
    reg [1:0] p_reg_array [31:0];//hi and lo
    // write 
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
        if (p_we&& p_waddr[0]==1'b1)begin
            p_reg_array[1]<=p_wdata[63:32];//lo
            p_reg_array[0]<=p_wdata[31:0];//hi
        end
        else if(p_we&& p_waddr[0]==1'b0&&p_waddr[1]==1'b1)begin
            p_reg_array[1]<=p_wdata[63:32];//lo
        end
        else if(p_we&& p_waddr[0]==1'b0&&p_waddr[1]==1'b0)begin
             p_reg_array[0]<=p_wdata[31:0];//hi
        end
    end
    //regfile______________________________________________
    // read out 1
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 :
                     (raddr1==waddr)?wdata:reg_array[raddr1];

    // read out2
     assign rdata2 = (raddr2 == 5'b0) ? 32'b0 :
                     (raddr2==waddr)?wdata:reg_array[raddr2];
    //Èç¹ûÊÇ0ºÅ¼Ä´æÆ÷ rdata=0 ·ñÔò rdata=¼Ä´æÆ÷ÖÐµÄ´æ´¢Öµ
    //regfile______________________________________________
    
    //hilo_________________________________________________
    assign hilo_o = (p_waddr[0]==1'b0)&(p_waddr[1]==1'b0)&(p_raddr == p_waddr[1])?p_wdata[31:0]:
                     (p_waddr[0]==1'b0)&(p_waddr[1]==1'b1)&(p_raddr == p_waddr[1])?p_wdata[63:32]
                     :p_reg_array[p_raddr];
    //hilo_________________________________________________
    
endmodule