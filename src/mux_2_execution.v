`timescale 1ns / 1ps

module mux_2_execution(
input zero,
input [31:0] immediate,
input [31:0] PC_out,
output [31:0] PC_calculated    );
wire [31:0] PC_if_branch;
assign PC_if_branch = (PC_out+4)+(immediate<<2);
assign PC_calculated = zero?PC_if_branch:PC_out+4;
endmodule
