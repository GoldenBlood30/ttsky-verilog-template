`timescale 1ns / 1ps

module Write_back_mux(
input [31:0] MEM_WB_Rd_data,
input [31:0] MEM_WB_R,
input Mem_to_Reg,
output [31:0] write_data
    );
 assign write_data = Mem_to_Reg? MEM_WB_Rd_data:MEM_WB_R;

endmodule
