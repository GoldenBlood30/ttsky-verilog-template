`timescale 1ns / 1ps

module mux_1_execution(
input [31:0] rt_f,
input [31:0] ID_EX_immediate,
input Alu_src,
output [31:0] operand_2  );
   assign operand_2 = Alu_src?ID_EX_immediate:rt_f;
endmodule
