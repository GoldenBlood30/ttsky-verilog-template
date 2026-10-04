`timescale 1ns / 1ps

module ALU(
input [31:0] operand_1,      // result of Forward_rs mux
input [31:0] operand_2,      // result of ALUSrc mux
input [1:0] ALUOp,           // ID_EX_EX[2:1]
output reg [31:0] R,
output zero, // zero status
// Flag outputs (x86-style, for CSR[7:2]): raw flags of this cycle's ALU op.
// They travel down the pipeline with the instruction and are committed to the
// CSR at writeback only for add/sub/addi/beq (control_unit FL).
output reg CF,   // unsigned carry out (ADD) / borrow (SUB)
output     SF,   // result MSB (negative)
output reg OF,   // signed overflow
output     PF,   // even parity of R[7:0]
output reg AF    // nibble (bit3->bit4) carry/borrow, for BCD
    );

// 33-bit extension gives the ADD carry-out directly.
wire [32:0] add_ext = {1'b0, operand_1} + {1'b0, operand_2};

always @(*)
begin
    case(ALUOp)
        2'b00: begin                        // ADD, ADDI, LW, SW
            R  = operand_1 + operand_2;
            CF = add_ext[32];
            OF = (operand_1[31] == operand_2[31]) && (R[31] != operand_1[31]);
            AF = ({1'b0, operand_1[3:0]} + {1'b0, operand_2[3:0]}) > 5'h0F;  // 5 bits keeps the nibble carry
        end
        2'b10: begin                        // SUB, BEQ
            R  = operand_1 - operand_2;
            CF = (operand_1 < operand_2);   // unsigned borrow
            OF = (operand_1[31] != operand_2[31]) && (R[31] != operand_1[31]);
            AF = (operand_1[3:0] < operand_2[3:0]);
        end
        default: begin
            R  = 32'b0;
            CF = 1'b0;
            OF = 1'b0;
            AF = 1'b0;
        end
    endcase
end

assign zero = (R == 32'b0);
assign SF   = R[31];
assign PF   = ~^R[7:0];   // XNOR-reduce: 1 when low byte has an even number of set bits

endmodule
