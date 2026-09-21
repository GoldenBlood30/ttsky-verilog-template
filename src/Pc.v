`timescale 1ns / 1ps

module Pc(
input clk,
input PC_flush,
input PC_stall,
input [31:0] PC_in,
input [31:0] PC_calculated,
input        hold,
input        rst,
output reg [31:0] PC_out
    );
    always @ (posedge clk or posedge rst)
    begin
    if(rst)
    begin
        PC_out <= 32'h00000000;
    end
    else if(hold)
    begin
        PC_out <= PC_out;
    end
    else if(PC_flush)
    begin
    PC_out<=PC_calculated;
    end
    else if(PC_stall)
    begin
    PC_out<=PC_out;
    end
    else
    PC_out<=PC_in;
    end
endmodule
