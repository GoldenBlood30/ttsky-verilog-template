`timescale 1ns / 1ps

module M_WB_Register(
input rst,
input clk,
input [1:0] EX_MEM_WB,
input [31:0] Rd_data,
input [31:0] EX_MEM_R,
input [4:0] EX_MEM_rd,
input freeze,
output reg  [1:0] MEM_WB_WB,
output reg  [31:0] MEM_WB_Rd_data,
output reg  [31:0] MEM_WB_R,
output reg  [4:0] MEM_WB_rd
    );
    always @ (posedge clk or posedge rst)
    begin
    if(rst)
    begin
MEM_WB_WB<=2'b00;
MEM_WB_Rd_data<={32{1'b0}};
MEM_WB_R<={32{1'b0}};
MEM_WB_rd<=5'b0000;
end
else if (freeze)
begin
 MEM_WB_WB<=MEM_WB_WB;
 MEM_WB_Rd_data<=MEM_WB_Rd_data;
 MEM_WB_R<=MEM_WB_R;
 MEM_WB_rd<=MEM_WB_rd;
end
else
begin
MEM_WB_WB<=EX_MEM_WB;
MEM_WB_Rd_data<=Rd_data;
MEM_WB_R<=EX_MEM_R;
MEM_WB_rd<=EX_MEM_rd;
end
end
endmodule
