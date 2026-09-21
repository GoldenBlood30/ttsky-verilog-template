`timescale 1ns / 1ps

module Forward_rs(
input [1:0] forward_rs,
input [31:0] D_1,
input [31:0] Mem_WB_write_data,
input [31:0] EX_MEM_R,
 output reg [31:0] operand_1);
 always @ (*)
 begin
 case (forward_rs)
 2'b10:operand_1=EX_MEM_R;
 2'b11:operand_1=Mem_WB_write_data;
 2'b00:operand_1=D_1;
 default:operand_1={32{1'b0}};
 endcase
 end
endmodule
