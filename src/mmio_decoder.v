`timescale 1ns / 1ps

// MMIO map (IMEM/DMEM depth set by IM_AW / DM_AW, parameters of custom_risc_v_core):
//   0x0000 .. 0x0000+4*(2**IM_AW)-4 : IMEM,    2**IM_AW x 32-bit words
//   0x1000-0x107C : REGFILE, R0-R31
//   0x2000 .. 0x2000+4*(2**DM_AW)-4 : DMEM,    2**DM_AW x 32-bit words
// Word addresses beyond the implemented depth are UNMAPPED: writes are
// ignored and reads return 0x0DEADBEE (they never alias onto real words).
//   0x3000        : CSR      (bit0 RUN [writable], bit1 DONE,
//                              bit2 ZF, bit3 CF, bit4 SF, bit5 OF,
//                              bit6 PF, bit7 AF -- flags of the last
//                              add/sub/addi/beq to reach writeback;
//                              read-only, cleared only by reset)
//   0x3004        : TARGET_PC
//   0x3008        : live PC (read-only)
module mmio_decoder #(
    parameter IM_AW = 5,
    parameter DM_AW = 4
) (
    input        clk,
    input        rst,
    input        mmio_wr,
    input [15:0] mmio_addr,
    input [31:0] mmio_wdata,
    input        done,
    input [5:0]  flags_in,   // {AF,PF,OF,SF,CF,ZF} -> csr[7:2]
    input        flags_we,   // MEM/WB instruction commits flags (FL)
    output       imem_prog_we,
    output [7:0] imem_prog_addr,
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
    // plus the live PC at 0x3008. Unmapped addresses read 0x0DEADBEE.
    input [31:0] imem_rdata,
    input [31:0] regfile_rdata,
    input [31:0] dmem_rdata,
    input [31:0] pc,
    output reg [31:0] mmio_rdata
);

    // Region hits (word index must be inside the implemented depth).
    wire imem_hit = (mmio_addr[15:10] == 6'd0) && (mmio_addr[9:2] < (1 << IM_AW));
    wire dmem_hit = (mmio_addr[15:8] == 8'h20) && (mmio_addr[7:2] < (1 << DM_AW));

    // IMEM
    assign imem_prog_we    = mmio_wr && imem_hit &&
                             (mmio_addr[1:0] == 2'b00);
    assign imem_prog_addr  = mmio_addr[9:2];
    assign imem_prog_wdata = mmio_wdata;

    // REGFILE: 0x1000-0x107C (32 x 4 bytes = 128 bytes) - unchanged size
    assign regfile_prog_we    = mmio_wr && (mmio_addr >= 16'h1000) &&
                                (mmio_addr <= 16'h107C) &&
                                (mmio_addr[1:0] == 2'b00);
    assign regfile_prog_addr  = mmio_addr[6:2];
    assign regfile_prog_wdata = mmio_wdata;

    // DMEM
    assign dmem_prog_we    = mmio_wr && dmem_hit &&
                             (mmio_addr[1:0] == 2'b00);
    assign dmem_prog_addr  = mmio_addr[7:2];
    assign dmem_prog_wdata = mmio_wdata;

    // The *_prog_addr outputs above already index the memories, so each
    // memory's rdata is the word at mmio_addr.
    always @(*) begin
        if (imem_hit)
            mmio_rdata = imem_rdata;
        else if ((mmio_addr >= 16'h1000) && (mmio_addr <= 16'h107C))
            mmio_rdata = regfile_rdata;
        else if (dmem_hit)
            mmio_rdata = dmem_rdata;
        else if (mmio_addr == 16'h3000)
            mmio_rdata = {24'd0, csr};
        else if (mmio_addr == 16'h3004)
            mmio_rdata = target_pc;
        else if (mmio_addr == 16'h3008)
            mmio_rdata = pc;
        else
            mmio_rdata = 32'h0DEADBEE;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            csr       <= 8'h00;
            target_pc <= 32'h00000000;
        end else begin
            csr[1]   <= done;
            if (flags_we)
                csr[7:2] <= flags_in;
            if (mmio_wr && (mmio_addr == 16'h3000))
                csr[0] <= mmio_wdata[0];
            if (mmio_wr && (mmio_addr == 16'h3004))
                target_pc <= mmio_wdata;
        end
    end
endmodule
