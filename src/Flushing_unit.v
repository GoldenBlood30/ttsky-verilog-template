`timescale 1ns / 1ps

module Flushing_unit(
input comparator ,
input [31:0] IF_ID_PC_out,
input [31:0] PC_calculated ,
output reg IF_ID_flush,
output reg PC_flush,
output reg ID_EX_flush
    );
    always @ (*)
    begin
    if((comparator==0)&&~(IF_ID_PC_out==PC_calculated))
    begin
    {IF_ID_flush,PC_flush,ID_EX_flush}=3'b111;
    end
    else
    begin
    {IF_ID_flush,PC_flush,ID_EX_flush}=3'b000;
    end
    end
endmodule
