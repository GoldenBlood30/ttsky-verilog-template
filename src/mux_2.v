`timescale 1ns / 1ps

module mux_2(
input rst,
input [31:0] PC_out,
input [31:0] PC_prediction_if_branch,
input comparator,
output [31:0] PC_in
    );
    assign PC_in = rst?{32{1'b0}}:(comparator==0)?PC_prediction_if_branch:PC_out+4;
endmodule
