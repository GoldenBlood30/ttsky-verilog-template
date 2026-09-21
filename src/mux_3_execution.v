`timescale 1ns / 1ps

module mux_3_execution(
input [4:0] ID_EX_rd_maybe,
input [4:0] ID_EX_rt,
input Reg_dst,
output [4:0] rd
 );
 assign rd = Reg_dst?ID_EX_rt:ID_EX_rd_maybe;
endmodule
