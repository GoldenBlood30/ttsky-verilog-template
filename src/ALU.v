`timescale 1ns / 1ps

module ALU(
input [31:0] operand_1,      // result of Forward_rs mux
input [31:0] operand_2,      // result of ALUSrc mux
input [1:0] ALUOp,           // ID_EX_EX[2:1]
output reg [31:0] R,
output zero // zero status
    );

always @(*)
begin
    case(ALUOp)
        2'b00: R = operand_1 + operand_2;   // ADD, ADDI, LW, SW
        2'b10: R = operand_1 - operand_2;   // SUB, BEQ
        default: R = 32'b0;
    endcase
end

assign zero = (R == 32'b0);

endmodule
