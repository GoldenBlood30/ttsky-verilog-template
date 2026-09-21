`timescale 1ns / 1ps

module forward_rt(
input [1:0] forward_rt,
input [31:0] D_2,
input [31:0] Mem_WB_write_data,
input [31:0] EX_MEM_R,
 output reg [31:0] rt_f
    );
    always @ (*)
    begin
    case (forward_rt)
    2'b10:rt_f=EX_MEM_R;
    2'b11:rt_f=Mem_WB_write_data;
    2'b00:rt_f=D_2;
    default:rt_f={32{1'b0}};
    endcase
    end
endmodule
