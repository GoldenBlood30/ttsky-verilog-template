# 5-Stage Pipelined MIPS with I2C/MMIO Loader

## How it works

This is a 5-stage pipelined MIPS-style CPU (fetch, decode, execute, memory,
writeback) with:
- Full data-hazard forwarding (EX/MEM and MEM/WB paths, including a
  write-first bypass in the register file for the one same-cycle
  WB-write/ID-read case not covered by pipeline forwarding)
- Load-use hazard detection with automatic pipeline stalling
- Dynamic branch prediction (BHT + BTB + PHT-indexed pattern history) with
  correct misprediction recovery and pipeline flush

Because the on-chip instruction memory, data memory, and register file are
all normally fixed at synthesis time, this design adds a memory-mapped I2C
loader so the entire program state can be reprogrammed after the chip is
fabricated:

| MMIO Address Range | Region |
|---|---|
| 0x0000 - 0x00FC | Instruction memory (64 words) |
| 0x1000 - 0x107C | Register file (32 registers, R0 write-protected) |
| 0x2000 - 0x20FC | Data memory (64 words) |
| 0x3000 | CSR (bit 0 = RUN) |
| 0x3004 | TARGET_PC (halt address) |

The pipeline is held frozen while `RUN=0`. Writing `RUN=1` releases it to
execute from address 0. Once the program counter reaches `TARGET_PC`, fetch
is blocked, in-flight instructions are allowed to drain to completion, and
`DONE` asserts (driven out on the `led` pin).

Instruction memory and data memory were sized down to 64 words each
(from an original 256-word version) specifically to fit Tiny Tapeout's
area budget -- both are implemented as plain flip-flop arrays (no SRAM
macros in this flow), and 64 words was chosen with margin above the
actual minimum needed by the included test program (which uses IMEM
addresses up to 0x84 and DMEM addresses up to 21).

## How to test

1. Hold reset (`rst_n` low), then release it.
2. Over I2C (7-bit slave address `0x42`), send a sequence of 7-byte write
   frames -- `[CMD][ADDR_HI][ADDR_LO][D3][D2][D1][D0]` -- to load your
   program into instruction memory, optionally preload data memory or
   register file values, and set `TARGET_PC`.
3. Write `CSR = 0x00000001` to release the pipeline and start execution.
4. Poll the `led` pin (or watch for it going high) to know when execution
   has completed.

A single 32-bit MMIO write takes 63 SCL clocks (9 for the address+ACK, 18
for the 16-bit MMIO address, 36 for the 32-bit data, all including ACKs).

Note: `TARGET_PC` must be an address your program's real (taken) control
flow actually revisits -- if a branch skips over it entirely, the design
will wait indefinitely for `DONE` rather than corrupting anything.

## External hardware

None required beyond an I2C master (e.g. a microcontroller) wired to
`ui_in[0]` (SCL) and `uio[0]` (SDA, open-drain, needs a pull-up if your
setup doesn't already provide one).
