`timescale 1ns / 1ps

module ID_EX_register(
input rst,
input clk,
input ID_EX_flush,
input ID_EX_stall,
input freeze,
input [3:0] EX,
input [1:0] M,
input [1:0] WB,
input [4:0] rs,
input [4:0] rt,
input [31:0] D_1,
input [31:0] D_2,
input  comparator,
input  [4:0] rd_maybe,
input  [31:0] immediate,
input  [31:0] PC_out,
input  [3:0] BHT_rd_addr,
output reg [3:0] ID_EX_EX,
output reg [1:0] ID_EX_M,
output reg [1:0] ID_EX_WB,
output reg [4:0] ID_EX_rs,
output reg [4:0] ID_EX_rt,
output reg [31:0] ID_EX_D_1,
output reg [31:0] ID_EX_D_2,
output reg  ID_EX_comparator,
output reg  [4:0] ID_EX_rd_maybe,
output reg  [31:0] ID_EX_immediate,
output reg  [31:0] ID_EX_PC_out,
output reg  [3:0] ID_EX_BHT_rd_addr
);
always @ (posedge clk or posedge rst)
begin
if(rst)
begin
 ID_EX_EX<=4'b0000;
 ID_EX_M<=2'b00;
 ID_EX_WB<=2'b00;
 ID_EX_rs<=5'b00000;
 ID_EX_rt<=5'b00000;
 ID_EX_D_1<={32{1'b0}};
 ID_EX_D_2<={32{1'b0}};
 ID_EX_comparator<=1'b1;
 ID_EX_rd_maybe<=5'b00000;
  ID_EX_immediate<={32{1'b0}};
  ID_EX_PC_out<={32{1'b0}};
 ID_EX_BHT_rd_addr<=4'b0000;
end
else if (freeze)
begin
 // Hold the entire pipeline register during LOAD/HALT.
 ID_EX_EX<=ID_EX_EX;
 ID_EX_M<=ID_EX_M;
 ID_EX_WB<=ID_EX_WB;
 ID_EX_rs<=ID_EX_rs;
 ID_EX_rt<=ID_EX_rt;
 ID_EX_D_1<=ID_EX_D_1;
 ID_EX_D_2<=ID_EX_D_2;
 ID_EX_comparator<=ID_EX_comparator;
 ID_EX_rd_maybe<=ID_EX_rd_maybe;
 ID_EX_immediate<=ID_EX_immediate;
 ID_EX_PC_out<=ID_EX_PC_out;
 ID_EX_BHT_rd_addr<=ID_EX_BHT_rd_addr;
end
else if (ID_EX_flush)
begin
 ID_EX_EX<=4'b0000;
 ID_EX_M<=2'b00;
 ID_EX_WB<=2'b00;
 ID_EX_rs<=5'b00000;
 ID_EX_rt<=5'b00000;
 ID_EX_D_1<={32{1'b0}};
 ID_EX_D_2<={32{1'b0}};
 ID_EX_comparator<=1'b1;
 ID_EX_rd_maybe<=5'b00000;
  ID_EX_immediate<={32{1'b0}};
  ID_EX_PC_out<={32{1'b0}};
 ID_EX_BHT_rd_addr<=4'b0000;
end
else if (ID_EX_stall)
begin
 ID_EX_EX<=4'b0000;
 ID_EX_M<=2'b00;
 ID_EX_WB<=2'b00;
 ID_EX_rs<=5'b00000;
 ID_EX_rt<=5'b00000;
 ID_EX_D_1<={32{1'b0}};
 ID_EX_D_2<={32{1'b0}};
 ID_EX_comparator<=1'b1;
 ID_EX_rd_maybe<=5'b00000;
  ID_EX_immediate<={32{1'b0}};
  ID_EX_PC_out<={32{1'b0}};
 ID_EX_BHT_rd_addr<=4'b0000;
end
else
begin
 ID_EX_EX<=EX ;
 ID_EX_M<=M;
 ID_EX_WB<=WB;
 ID_EX_rs<=rs;
 ID_EX_rt<=rt;
 ID_EX_D_1<=D_1;
 ID_EX_D_2<=D_2;
 ID_EX_comparator<=comparator;
 ID_EX_rd_maybe<=rd_maybe;
  ID_EX_immediate<=immediate;
  ID_EX_PC_out<=PC_out;
 ID_EX_BHT_rd_addr<=BHT_rd_addr;
 end
end
endmodule
