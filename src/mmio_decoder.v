`timescale 1ns / 1ps

// MMIO map (resized for the 64-word IMEM/DMEM):
//   0x0000-0x00FC : IMEM,    64 x 32-bit words
//   0x1000-0x107C : REGFILE, R0-R31
//   0x2000-0x20FC : DMEM,    64 x 32-bit words
//   0x3000        : CSR      (bit0 RUN, bit1 DONE)
//   0x3004        : TARGET_PC
//   0x3008        : live PC (read-only)
module mmio_decoder(
    input        clk,
    input        rst,
    input        mmio_wr,
    input [15:0] mmio_addr,
    input [31:0] mmio_wdata,
    input        done,
    output       imem_prog_we,
    output [5:0] imem_prog_addr,
    output [31:0] imem_prog_wdata,
    output       regfile_prog_we,
    output [4:0] regfile_prog_addr,
    output [31:0] regfile_prog_wdata,
    output       dmem_prog_we,
    output [5:0] dmem_prog_addr,
    output [31:0] dmem_prog_wdata,
    output reg [7:0] csr,
    output reg [31:0] target_pc,
    // I2C readback: every writable address reads back its current value,
    // plus the live PC at 0x3008. Unmapped addresses read 0xDEADBEEF.
    input [31:0] imem_rdata,
    input [31:0] regfile_rdata,
    input [31:0] dmem_rdata,
    input [31:0] pc,
    output reg [31:0] mmio_rdata
);

    // IMEM: 0x0000-0x00FF (64 words x 4 bytes = 256 bytes)
    assign imem_prog_we    = mmio_wr && (mmio_addr[15:8] == 8'h00) &&
                             (mmio_addr[1:0] == 2'b00);
    assign imem_prog_addr  = mmio_addr[7:2];
    assign imem_prog_wdata = mmio_wdata;

    // REGFILE: 0x1000-0x107C (32 x 4 bytes = 128 bytes) - unchanged size
    assign regfile_prog_we    = mmio_wr && (mmio_addr >= 16'h1000) &&
                                (mmio_addr <= 16'h107C) &&
                                (mmio_addr[1:0] == 2'b00);
    assign regfile_prog_addr  = mmio_addr[6:2];
    assign regfile_prog_wdata = mmio_wdata;

    // DMEM: 0x2000-0x20FF (64 words x 4 bytes = 256 bytes)
    assign dmem_prog_we    = mmio_wr && (mmio_addr[15:8] == 8'h20) &&
                             (mmio_addr[1:0] == 2'b00);
    assign dmem_prog_addr  = mmio_addr[7:2];
    assign dmem_prog_wdata = mmio_wdata;

    // The *_prog_addr outputs above already index the memories, so each
    // memory's rdata is the word at mmio_addr.
    always @(*) begin
        if (mmio_addr[15:8] == 8'h00)
            mmio_rdata = imem_rdata;
        else if ((mmio_addr >= 16'h1000) && (mmio_addr <= 16'h107C))
            mmio_rdata = regfile_rdata;
        else if (mmio_addr[15:8] == 8'h20)
            mmio_rdata = dmem_rdata;
        else if (mmio_addr == 16'h3000)
            mmio_rdata = {30'd0, csr[1:0]};
        else if (mmio_addr == 16'h3004)
            mmio_rdata = target_pc;
        else if (mmio_addr == 16'h3008)
            mmio_rdata = pc;
        else
            mmio_rdata = 32'hDEADBEEF;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            csr       <= 8'h00;
            target_pc <= 32'h00000000;
        end else begin
            csr[1] <= done;
            if (mmio_wr && (mmio_addr == 16'h3000))
                csr[0] <= mmio_wdata[0];
            if (mmio_wr && (mmio_addr == 16'h3004))
                target_pc <= mmio_wdata;
        end
    end
endmodule
