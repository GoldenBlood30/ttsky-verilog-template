`timescale 1ns / 1ps

// Branch target buffer: 16 entries. Only the low BTB_W bits of each target
// are stored (upper bits read back as 0). Targets always lie inside the
// instruction memory, so BTB_W = IM_AW+3 covers every reachable PC including
// TARGET_PC. A wrong/stale prediction is always caught by the mispredict check
// in the EX stage (Flushing_unit) and corrected with the true target, so
// narrowing this table can never change program results.
module BTB (
input clk,
input [3:0] rd_addr,
input BTB_write_control,
input [3:0] ID_EX_PHT_wr_addr,
input [31:0] BTB_write_data,
input rst,
output [31:0] BTB_rd_data
    );
    localparam BTB_W = 7;   // = instruction_memory.v's IM_AW (4) + 3. Change both together.
    integer i;
    reg [BTB_W-1:0] btb_mem [15:0];
    assign BTB_rd_data = {{(32-BTB_W){1'b0}}, btb_mem[rd_addr]};
    always @ (posedge clk or posedge rst)
    begin
    if(rst)
    begin
    for(i=0;i<=15;i=i+1)
    btb_mem[i]<={BTB_W{1'b0}};
    end
    else if (BTB_write_control)
    begin
    btb_mem[ID_EX_PHT_wr_addr]<=BTB_write_data[BTB_W-1:0];
    end
    end
endmodule
