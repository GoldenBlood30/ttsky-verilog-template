`timescale 1ns / 1ps

module control_unit(
input rst,
input [5:0] opcode,
output reg [3:0] EX,
output reg [1:0] M,
output reg [1:0] WB
    );
    always @ (*)
    begin
    if(rst)
    begin
    {EX,M,WB}={4'b0000,2'b00,2'b00};
    end
    else
    begin
    case(opcode)
    6'b000000:{EX,M,WB}={4'b0000,2'b00,2'b10};//add
    6'b000001:{EX,M,WB}={4'b0100,2'b00,2'b10};//sub
    6'b000010:{EX,M,WB}={4'b1001,2'b00,2'b10};//addi
    6'b000011:{EX,M,WB}={4'b1001,2'b10,2'b11};//lw
    6'b000100:{EX,M,WB}={4'b1001,2'b01,2'b01};//sw
    6'b000101:{EX,M,WB}={4'b0100,2'b00,2'b00};//beq
    default:{EX,M,WB}={4'b0000,2'b00,2'b00};
    endcase
    end
    end
endmodule
