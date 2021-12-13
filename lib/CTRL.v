`include "lib/defines.vh"
module CTRL(
    input wire rst,
//    input wire stallreq_for_ex,
//    input wire stallreq_for_load,

    // output reg flush,
    // output reg [31:0] new_pc,
    input wire stall_for_id,
    input wire stall_for_ex,
    output reg [`StallBus-1:0] stall
);  
    always @ (*) begin
        if (rst) begin
            stall = `StallBus'b0;
        end else if(stall_for_id)begin
            stall = `StallBus'b000111;
        end else if(stall_for_ex)begin
            stall = `StallBus'b001111;
            end
        else begin
            stall = `StallBus'b0;
        end
    end

endmodule