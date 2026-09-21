`timescale 1ns / 1ps

module branching_unit(
input comparator ,
input [31:0] IF_ID_PC_out,
input [31:0] PC_calculated ,
output reg PHT_write,
output reg BHT_write,
output reg BTB_write
    );
    always @ (*)
    begin
    {PHT_write,BHT_write,BTB_write}=3'b000;
    if(~comparator)
    begin
    PHT_write=1'b1;
    end
    if((comparator==0)&&~(IF_ID_PC_out==PC_calculated))
    begin
    {PHT_write,BHT_write,BTB_write}=3'b111;
    end
    end
endmodule
