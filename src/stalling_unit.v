`timescale 1ns / 1ps

module stalling_unit(
input [31:0] IF_ID_IC,
input rst,
input ID_EX_MEM_Rd,
input [4:0] ID_EX_rt,
input [4:0] IF_ID_rs,
input [4:0] IF_ID_rt,
output reg  IF_ID_stall,
output reg  ID_EX_stall,
output reg  PC_stall   );
always @ (*)
begin
if(rst)
begin
{IF_ID_stall,ID_EX_stall,PC_stall}={1'b0,1'b0,1'b0};
end
else if (
    ID_EX_MEM_Rd &&
    (
        (IF_ID_rs == ID_EX_rt)
        ||
        (
            (IF_ID_rt == ID_EX_rt) &&
            (IF_ID_IC[31:26] != 6'b000010) &&
            (IF_ID_IC[31:26] != 6'b000011)
        )
    )
)
begin
{IF_ID_stall,ID_EX_stall,PC_stall}={1'b1,1'b1,1'b1};
end
else
begin
{IF_ID_stall,ID_EX_stall,PC_stall}={1'b0,1'b0,1'b0};
end
end
endmodule
