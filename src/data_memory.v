`timescale 1ns / 1ps

// 64 x 32-bit data memory (2048 bits total, matches the target size table).
// Resized from the original 256-word version to fit the Tiny Tapeout
// sky130 area budget.
// CPU addressing remains WORD-indexed to preserve the existing MIPS program:
// LW/SW address 7 accesses DM[7], address 20 accesses DM[20], etc.
// Only the low 6 address bits are used, so LW/SW addresses must stay in
// 0-63.
module data_memory(
    input        clk,
    input        rst,
    input        Mem_rd,
    input        Mem_write,
    input [31:0] rd_addr,
    input [31:0] write_data,
    output reg [31:0] rd_data,
    input        prog_we,
    input [5:0]  prog_addr,
    input [31:0] prog_wdata,
    output [31:0] prog_rdata
);
    integer i;
    reg [31:0] DM [63:0];

    // I2C readback of DM[prog_addr].
    assign prog_rdata = DM[prog_addr];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i <= 63; i = i + 1)
                DM[i] <= 32'd0;
        end else begin
            if (Mem_write)
                DM[rd_addr[5:0]] <= write_data;
            if (prog_we)
                DM[prog_addr] <= prog_wdata;
        end
    end

    always @(*) begin
        if (Mem_rd)
            rd_data = DM[rd_addr[5:0]];
        else
            rd_data = 32'b0;
    end
endmodule
