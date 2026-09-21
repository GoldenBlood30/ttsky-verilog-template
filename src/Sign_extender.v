`timescale 1ns / 1ps

module Sign_extender(
input [15:0] imm,
output [31:0] immediate );
assign immediate = {{16{imm[15]}},imm[15:0]};
endmodule
