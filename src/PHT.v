`timescale 1ns / 1ps

module PHT(
input clk,
input [3:0] rd_addr,
input PHT_write_control,
input [3:0] ID_EX_PHT_wr_addr,
input PHT_write_data,
input rst,
output [3:0] PHT_rd_data
    );
    integer i;
    reg [3:0] pht_mem [15:0];
    assign PHT_rd_data = pht_mem[rd_addr];
    always @ (posedge clk or posedge rst)
    begin
    if(rst)
    begin
    for(i=0;i<=15;i=i+1)
    pht_mem[i]<=4'b0000;
    end
    else if(PHT_write_control)
    begin
    pht_mem[ID_EX_PHT_wr_addr]<={pht_mem[ID_EX_PHT_wr_addr][2],pht_mem[ID_EX_PHT_wr_addr][1],pht_mem[ID_EX_PHT_wr_addr][0],PHT_write_data};
    end
    end
endmodule
