`timescale 1ns / 1ps

module BHT(
input clk,
input [3:0] rd_addr,
input BHT_write_control,
input [3:0] ID_EX_BHT_wr_addr,
input BHT_write_data,
input rst,
output  BHT_rd_data
    );
    integer i;
    reg [0:0] bht_mem [15:0];
    assign BHT_rd_data = bht_mem[rd_addr];
    always @ (posedge clk or posedge rst)
    begin
    if(rst)
    begin
    for(i=0;i<=15;i=i+1)
    bht_mem[i]<=1'b0;
    end
    else if (BHT_write_control)
    begin
    bht_mem[ID_EX_BHT_wr_addr]<=BHT_write_data;
    end
    end
endmodule
