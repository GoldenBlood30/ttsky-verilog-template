`timescale 1ns / 1ps

// FL (flag write): 1 for the instructions whose ALU flags are committed to
// CSR[7:2] at writeback -- add, sub, addi, and beq (a compare: flags of rs-rt).
// lw/sw address arithmetic and bubbles leave the flags alone.
module control_unit(
input rst,
input [5:0] opcode,
output reg [3:0] EX,
output reg [1:0] M,
output reg [1:0] WB,
output reg FL
    );
    always @ (*)
    begin
    if(rst)
    begin
    {EX,M,WB,FL}={4'b0000,2'b00,2'b00,1'b0};
    end
    else
    begin
    case(opcode)
    6'b000000:{EX,M,WB,FL}={4'b0000,2'b00,2'b10,1'b1};//add
    6'b000001:{EX,M,WB,FL}={4'b0100,2'b00,2'b10,1'b1};//sub
    6'b000010:{EX,M,WB,FL}={4'b1001,2'b00,2'b10,1'b1};//addi
    6'b000011:{EX,M,WB,FL}={4'b1001,2'b10,2'b11,1'b0};//lw
    6'b000100:{EX,M,WB,FL}={4'b1001,2'b01,2'b01,1'b0};//sw
    6'b000101:{EX,M,WB,FL}={4'b0100,2'b00,2'b00,1'b1};//beq
    default:{EX,M,WB,FL}={4'b0000,2'b00,2'b00,1'b0};
    endcase
    end
    end
endmodule
