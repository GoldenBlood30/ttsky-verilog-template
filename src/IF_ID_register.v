`timescale 1ns / 1ps
module IF_ID_register(
input clk,
input [31:0] instruction_code,
input  comparator,
input [31:0] PC_out,
input [3:0] BHT_rd_addr,
input IF_ID_stall,
input IF_ID_flush,
input rst,
input stop_fetch,
input freeze,
output reg [31:0] IF_ID_instruction_code,
output reg IF_ID_comparator,
output reg [31:0] IF_ID_PC_out,
output reg [3:0] IF_ID_BHT_rd_addr
 );
 always @ (posedge clk or posedge rst)
 begin
 if(rst)
 begin
 IF_ID_instruction_code<={6'b111111,{26{1'b0}}};
 IF_ID_comparator<=1;
 IF_ID_PC_out<={32{1'b0}};
 IF_ID_BHT_rd_addr<=4'b0000;
 end
 else if (freeze)
 begin
 IF_ID_instruction_code<=IF_ID_instruction_code;
 IF_ID_comparator<=IF_ID_comparator;
 IF_ID_PC_out<=IF_ID_PC_out;
 IF_ID_BHT_rd_addr<=IF_ID_BHT_rd_addr;
 end
 else if (IF_ID_stall)
 begin
 IF_ID_instruction_code<=IF_ID_instruction_code;
 IF_ID_comparator<=IF_ID_comparator;
 IF_ID_PC_out<=IF_ID_PC_out;
 IF_ID_BHT_rd_addr<=IF_ID_BHT_rd_addr;
 end
 else if (stop_fetch)
 begin
 IF_ID_instruction_code<={6'b111111,{26{1'b0}}};
 IF_ID_comparator<=1;
 IF_ID_PC_out<=32'b0;
 IF_ID_BHT_rd_addr<=4'b0;
 end
 else if (IF_ID_flush)
 begin
 IF_ID_instruction_code<={6'b111111,{26{1'b0}}};
 IF_ID_comparator<=1;
 IF_ID_PC_out<={32{1'b0}};
 IF_ID_BHT_rd_addr<=4'b0000;
 end
 else
 begin
 IF_ID_instruction_code<=instruction_code;
 IF_ID_comparator<=comparator;
 IF_ID_PC_out<=PC_out;
 IF_ID_BHT_rd_addr<=BHT_rd_addr;
 end
 end
endmodule
