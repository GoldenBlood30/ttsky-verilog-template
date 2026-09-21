`timescale 1ns / 1ps

module mux_1(
input [31:0] PC_out,
input  [31:0] BTB_rd_data ,
input BHT_rd_data,
output [31:0] PC_prediction_if_branch
    );
    assign PC_prediction_if_branch = BHT_rd_data?BTB_rd_data:(PC_out+4);
endmodule
