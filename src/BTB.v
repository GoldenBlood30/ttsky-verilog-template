`timescale 1ns / 1ps

module BTB(
input clk,
input [3:0] rd_addr,
input BTB_write_control,
input [3:0] ID_EX_PHT_wr_addr,
input [31:0] BTB_write_data,
input rst,
output [31:0] BTB_rd_data
    );
    integer i;
    reg [31:0] btb_mem [15:0];
    assign BTB_rd_data = btb_mem[rd_addr];
    always @ (posedge clk or posedge rst)
    begin
    if(rst)
    begin
    for(i=0;i<=15;i=i+1)
    btb_mem[i]<={32{1'b0}};
    end
    else if (BTB_write_control)
    begin
    btb_mem[ID_EX_PHT_wr_addr]<=BTB_write_data;
    end
    end
endmodule
