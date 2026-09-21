`timescale 1ns / 1ps

module Xor_result(
input [3:0] PHT_rd_data,
input [3:0] PHT_rd_addr,
output [3:0] BHT_rd_addr
    );
    assign BHT_rd_addr=PHT_rd_data^PHT_rd_addr;
endmodule
