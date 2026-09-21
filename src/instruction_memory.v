`timescale 1ns / 1ps

// 256-BYTE (64 x 32-bit word) byte-addressed instruction memory.
// Resized from the original 1KB/256-word version to fit the Tiny Tapeout
// sky130 area budget (2048 bits total, matches the target size table).
// CPU fetch keeps the original byte-addressed PC convention.
// Programming writes one 32-bit instruction at a time, MSB first.
//
// Valid byte addresses: 0x00 - 0xFC (64 words). PC bits above [7:0] are
// ignored by the array index, so a program must not run past word 63
// without TARGET_PC stopping it first (address wraps otherwise).
module instruction_memory(
    input        rst,
    input        clk,
    input [31:0] PC_out,
    output [31:0] instruction_code,
    input        prog_we,
    input [5:0]  prog_addr,
    input [31:0] prog_wdata,
    output [31:0] prog_rdata
);
    reg [7:0] IM [255:0];

    assign instruction_code = {IM[PC_out[7:0]], IM[PC_out[7:0]+8'd1],
                               IM[PC_out[7:0]+8'd2], IM[PC_out[7:0]+8'd3]};

    // I2C readback: the word at prog_addr, MSB first (same layout as writes).
    assign prog_rdata = {IM[{prog_addr,2'b00}], IM[{prog_addr,2'b00}+8'd1],
                         IM[{prog_addr,2'b00}+8'd2], IM[{prog_addr,2'b00}+8'd3]};

    always @(posedge clk) begin
        if (prog_we) begin
            IM[{prog_addr,2'b00}]       <= prog_wdata[31:24];
            IM[{prog_addr,2'b00}+8'd1]  <= prog_wdata[23:16];
            IM[{prog_addr,2'b00}+8'd2]  <= prog_wdata[15:8];
            IM[{prog_addr,2'b00}+8'd3]  <= prog_wdata[7:0];
        end
    end
endmodule
