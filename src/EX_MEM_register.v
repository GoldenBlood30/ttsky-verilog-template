`timescale 1ns / 1ps

module EX_MEM_Register(
input clk,
input rst,
input [1:0] ID_EX_M,
input [1:0] ID_EX_WB,
input [4:0] ID_EX_rs,
input [4:0] ID_EX_rt,
input [31:0] R,
input [31:0] rt_f,
input [4:0] rd,
input freeze,
output reg [1:0] EX_MEM_M,
output reg [1:0] EX_MEM_WB,
output reg [4:0] EX_MEM_rs,
output reg [4:0] EX_MEM_rt,
output reg [31:0] EX_MEM_R,
output reg [31:0] EX_MEM_rt_f,
output reg [4:0] EX_MEM_rd
    );
    always @ (posedge clk or posedge rst)
    begin
    if(rst)
    begin
EX_MEM_M<=2'b00;
EX_MEM_WB<=2'b00;
EX_MEM_rs<=5'b00000;
EX_MEM_rt<=5'b00000;
EX_MEM_R<={32{1'b0}};
EX_MEM_rt_f<={32{1'b0}};
EX_MEM_rd<=5'b00000;
    end
    else if (freeze)
    begin
        EX_MEM_M<=EX_MEM_M;
        EX_MEM_WB<=EX_MEM_WB;
        EX_MEM_rs<=EX_MEM_rs;
        EX_MEM_rt<=EX_MEM_rt;
        EX_MEM_R<=EX_MEM_R;
        EX_MEM_rt_f<=EX_MEM_rt_f;
        EX_MEM_rd<=EX_MEM_rd;
    end
    else
    begin
EX_MEM_M<=ID_EX_M;
EX_MEM_WB<=ID_EX_WB;
EX_MEM_rs<=ID_EX_rs;
EX_MEM_rt<=ID_EX_rt;
EX_MEM_R<=R;
EX_MEM_rt_f<=rt_f;
EX_MEM_rd<=rd;
    end
    end
endmodule
