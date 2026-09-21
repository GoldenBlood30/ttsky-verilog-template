`timescale 1ns / 1ps

module comparator(
input [31:0] instruction_code,
output comparator
    );
    assign comparator = (instruction_code[31:26]==6'b000101)?0:1;
endmodule
