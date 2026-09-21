`timescale 1ns / 1ps

// Write-only + readback I2C slave -> generic MMIO interface.
// Ports use split sda_in/sda_out/sda_oe instead of `inout` so the design
// stays free of top-level tri-state logic; the TT harness (or any wrapper)
// does the real electrical tri-stating at the pad.
//
// Write transaction:
//   [7-bit slave address + W] [ACK]
//   [addr15:8] [ACK] [addr7:0] [ACK]
//   [data31:24] [ACK] [data23:16] [ACK]
//   [data15:8]  [ACK] [data7:0] [ACK] STOP
//
// Read transaction (repeated START):
//   [0x42+W] [ACK] [addr15:8] [ACK] [addr7:0] [ACK]
//   Sr [0x42+R] [ACK] [data31:24] [ACK] ... [data7:0] [NACK] STOP
//
// All bytes MSB-first. mmio_wr is a one-system-clock pulse after the final
// data byte of a write has been received.
module i2c_slave_mmio #(
    parameter [6:0] SLAVE_ADDR = 7'h42
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        scl,
    input  wire        sda_in,
    output wire        sda_out,
    output reg          sda_oe,
    output reg          mmio_wr,
    output reg [15:0]   mmio_addr,
    output reg [31:0]   mmio_wdata,
    input  wire [31:0]  mmio_rdata
);

    assign sda_out = 1'b0; // open-drain: only ever pulls low

    reg [2:0] scl_s;
    reg [2:0] sda_s;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_s <= 3'b111;
            sda_s <= 3'b111;
        end else begin
            scl_s <= {scl_s[1:0], scl};
            sda_s <= {sda_s[1:0], sda_in};
        end
    end

    wire scl_now  = scl_s[1];
    wire scl_prev = scl_s[2];
    wire sda_now  = sda_s[1];
    wire sda_prev = sda_s[2];

    wire scl_rising  = (scl_prev == 1'b0) && (scl_now == 1'b1);
    wire scl_falling = (scl_prev == 1'b1) && (scl_now == 1'b0);

    wire start_cond = (sda_prev == 1'b1) && (sda_now == 1'b0) && scl_now;
    wire stop_cond  = (sda_prev == 1'b0) && (sda_now == 1'b1) && scl_now;

    localparam S_IDLE     = 3'd0,
               S_ADDR     = 3'd1,
               S_ACK_ADDR = 3'd2,
               S_DATA     = 3'd3,
               S_ACK_DATA = 3'd4,
               S_TX       = 3'd5,
               S_ACK_TX   = 3'd6;

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shifter;
    reg [2:0] byte_index;
    reg       addr_ok;
    reg       rw;
    reg [31:0] tx_word;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_IDLE;
            bit_cnt    <= 4'd0;
            shifter    <= 8'd0;
            byte_index <= 3'd0;
            addr_ok    <= 1'b0;
            sda_oe     <= 1'b0;
            mmio_wr    <= 1'b0;
            mmio_addr  <= 16'd0;
            mmio_wdata <= 32'd0;
            rw         <= 1'b0;
            tx_word    <= 32'd0;
        end else begin
            mmio_wr <= 1'b0;

            if (stop_cond) begin
                state      <= S_IDLE;
                bit_cnt    <= 4'd0;
                byte_index <= 3'd0;
                addr_ok    <= 1'b0;
                sda_oe     <= 1'b0;
            end else if (start_cond) begin
                state      <= S_ADDR;
                bit_cnt    <= 4'd0;
                shifter    <= 8'd0;
                byte_index <= 3'd0;
                addr_ok    <= 1'b0;
                sda_oe     <= 1'b0;
            end else begin
                case (state)

                    S_IDLE: begin
                        sda_oe <= 1'b0;
                    end

                    S_ADDR: begin
                        if (scl_rising) begin
                            shifter <= {shifter[6:0], sda_now};
                            bit_cnt <= bit_cnt + 1'b1;
                        end

                        if (scl_falling && bit_cnt == 4'd8) begin
                            if (shifter[7:1] == SLAVE_ADDR) begin
                                sda_oe  <= 1'b1;
                                addr_ok <= 1'b1;
                                state   <= S_ACK_ADDR;
                                rw      <= shifter[0];
                                tx_word <= mmio_rdata;
                            end else begin
                                sda_oe  <= 1'b0;
                                addr_ok <= 1'b0;
                                state   <= S_IDLE;
                            end
                            bit_cnt <= 4'd0;
                        end
                    end

                    S_ACK_ADDR: begin
                        if (scl_falling) begin
                            sda_oe     <= 1'b0;
                            shifter    <= 8'd0;
                            bit_cnt    <= 4'd0;
                            byte_index <= 3'd0;
                            state      <= S_DATA;

                            if (rw) begin
                                sda_oe <= ~tx_word[31];
                                state  <= S_TX;
                            end
                        end
                    end

                    S_DATA: begin
                        if (scl_rising) begin
                            shifter <= {shifter[6:0], sda_now};
                            bit_cnt <= bit_cnt + 1'b1;
                        end

                        if (scl_falling && bit_cnt == 4'd8) begin
                            case (byte_index)
                                3'd0: mmio_addr[15:8]   <= shifter;
                                3'd1: mmio_addr[7:0]    <= shifter;
                                3'd2: mmio_wdata[31:24] <= shifter;
                                3'd3: mmio_wdata[23:16] <= shifter;
                                3'd4: mmio_wdata[15:8]  <= shifter;
                                3'd5: begin
                                    mmio_wdata[7:0] <= shifter;
                                    mmio_wr <= 1'b1;
                                end
                                default: begin end
                            endcase

                            sda_oe  <= 1'b1;
                            bit_cnt <= 4'd0;
                            state   <= S_ACK_DATA;
                        end
                    end

                    S_ACK_DATA: begin
                        if (scl_falling) begin
                            sda_oe  <= 1'b0;
                            shifter <= 8'd0;
                            bit_cnt <= 4'd0;

                            if (byte_index == 3'd5) begin
                                byte_index <= 3'd0;
                                state      <= S_IDLE;
                            end else begin
                                byte_index <= byte_index + 1'b1;
                                state      <= S_DATA;
                            end
                        end
                    end

                    S_TX: begin
                        if (scl_falling) begin
                            tx_word <= {tx_word[30:0], 1'b1};
                            if (bit_cnt == 4'd7) begin
                                sda_oe  <= 1'b0;
                                bit_cnt <= 4'd0;
                                state   <= S_ACK_TX;
                            end else begin
                                sda_oe  <= ~tx_word[30];
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end

                    S_ACK_TX: begin
                        if (scl_rising && sda_now) begin
                            state <= S_IDLE;
                        end else if (scl_falling) begin
                            if (byte_index == 3'd3) begin
                                byte_index <= 3'd0;
                                state      <= S_IDLE;
                            end else begin
                                byte_index <= byte_index + 1'b1;
                                sda_oe     <= ~tx_word[31];
                                state      <= S_TX;
                            end
                        end
                    end

                    default: begin
                        state      <= S_IDLE;
                        bit_cnt    <= 4'd0;
                        byte_index <= 3'd0;
                        sda_oe     <= 1'b0;
                    end
                endcase
            end
        end
    end
endmodule
