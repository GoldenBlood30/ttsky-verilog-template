`timescale 1ns / 1ps

module Forwarding_unit(
input [4:0] ID_EX_rs,
input [4:0] ID_EX_rt,
input [4:0] EX_MEM_rd ,
input [4:0] MEM_WB_rd ,
input EX_MEM_Reg_write,
input MEM_WB_Reg_write,
output reg [1:0] forward_rs,
output reg [1:0] forward_rt);
always @ (*)
begin
forward_rs=2'b00;
forward_rt=2'b00;
if(EX_MEM_Reg_write && (EX_MEM_rd != 5'd0))   // r0 is hard-wired to 0: never forward a write to it
begin
if(EX_MEM_rd==ID_EX_rs)
begin
forward_rs=2'b10;
end
if(EX_MEM_rd==ID_EX_rt)
begin
forward_rt=2'b10;
end
end
if (MEM_WB_Reg_write && (MEM_WB_rd != 5'd0))   // r0 is hard-wired to 0: never forward a write to it
begin
if((MEM_WB_rd==ID_EX_rs)&&(~(EX_MEM_rd==ID_EX_rs)||~EX_MEM_Reg_write))
begin
forward_rs=2'b11;
end
if(MEM_WB_rd==ID_EX_rt  &&(~(EX_MEM_rd==ID_EX_rt)||~EX_MEM_Reg_write))
begin
forward_rt=2'b11;
end
end
end
endmodule
