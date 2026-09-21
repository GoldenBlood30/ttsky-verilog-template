`timescale 1ns / 1ps

module reg_file(
    input        clk,
    input        rst,
    input [4:0]  rs,
    input [4:0]  rt,
    input [4:0]  rd,
    input [31:0] write_data,
    input        Reg_write,
    output [31:0] D_1,
    output [31:0] D_2,
    input        prog_we,
    input [4:0]  prog_addr,
    input [31:0] prog_wdata,
    output [31:0] prog_rdata
);
    integer i;
    reg [31:0] RF [31:0];

    assign D_1 = (Reg_write && (rd == rs) && (rd != 5'd0)) ? write_data : RF[rs];
    assign D_2 = (Reg_write && (rd == rt) && (rd != 5'd0)) ? write_data : RF[rt];

    // I2C readback of register prog_addr.
    assign prog_rdata = RF[prog_addr];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i <= 31; i = i + 1)
                RF[i] <= i;
        end else begin
            if (prog_we && (prog_addr != 5'd0))
                RF[prog_addr] <= prog_wdata;
            else if (Reg_write && rd != 5'd0)
                RF[rd] <= write_data;
        end
    end
endmodule
