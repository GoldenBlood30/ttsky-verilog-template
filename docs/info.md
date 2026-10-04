# Reprogrammable Custom RISC-V Processor

## How it works

This is a reprogrammable 5-stage pipelined custom RISC-V processor (fetch,
decode, execute, memory, writeback). No program is hardened into the chip:
the instruction memory, data memory and register file are all loaded over
I2C after fabrication, and can be reloaded at any time.

The pipeline has:
- Full data-hazard forwarding (EX/MEM and MEM/WB paths, plus a write-first
  bypass in the register file for the same-cycle WB-write/ID-read case)
- Load-use hazard detection with automatic stalling
- Dynamic branch prediction (BHT + BTB + PHT pattern history) with
  misprediction recovery and pipeline flush
- x86-style ALU flags, committed to the CSR at writeback

### Instruction set

32-bit instructions, 32 registers (`r0` is hardwired to zero).
R-type: `opcode[31:26] rs[25:21] rt[20:16] rd[15:11]`;
I-type: `opcode[31:26] rs[25:21] rt[20:16] imm[15:0]`.

| Opcode | Instruction | Operation |
|---|---|---|
| 0x00 | `add rd, rs, rt` | rd = rs + rt |
| 0x01 | `sub rd, rs, rt` | rd = rs - rt |
| 0x02 | `addi rt, rs, imm` | rt = rs + sign_extend(imm) |
| 0x03 | `lw rt, imm(rs)` | rt = DMEM[rs + imm] (word address) |
| 0x04 | `sw rt, imm(rs)` | DMEM[rs + imm] = rt (word address) |
| 0x05 | `beq rs, rt, imm` | if rs == rt: PC = PC + 4 + 4*imm |
| 0x3F | `nop` (0xFC000000) | nothing |

`lw`/`sw` use word addresses, and only the low 4 bits are used: DMEM has
16 words, and higher addresses wrap.

### Memory map (over I2C)

| MMIO address | Region |
|---|---|
| 0x0000 - 0x00FC | Instruction memory (64 words) |
| 0x1000 - 0x107C | Register file (r0-r31, r0 always reads 0) |
| 0x2000 - 0x203C | Data memory (16 words) |
| 0x3000 | CSR (see below) |
| 0x3004 | TARGET_PC (halt address) |
| 0x3008 | Live PC (read-only) |

Any other address reads `0x0DEADBEE`, and writes to it are ignored.

CSR bits: 0 = RUN (the only writable bit), 1 = DONE, then the ALU flags of
the last `add`/`sub`/`addi`/`beq` to reach writeback (`beq` gives the
flags of rs - rt, like a compare): 2 = ZF, 3 = CF (carry / borrow),
4 = SF, 5 = OF (signed overflow), 6 = PF (even parity of the low byte),
7 = AF (carry / borrow out of bit 3). `lw`, `sw` and `nop` leave the flags
unchanged. Reset clears the CSR and data memory. Registers and instruction
memory have no reset: initialise every register a program reads.
Instruction memory, register and data memory readback is only valid while
the core is halted (`RUN=0` or `DONE=1`); it shares the CPU's read ports.

The pipeline is frozen while `RUN=0`. Writing `RUN=1` starts execution at
address 0. When the PC reaches `TARGET_PC`, fetch stops, the instructions
already in flight finish, and `DONE` goes high (also on the `led` pin).
End programs with at least two non-branch instructions before `TARGET_PC`,
and never branch to `TARGET_PC` itself.

## How to test

1. Hold reset (`rst_n` low), then release it.
2. Over I2C (7-bit slave address `0x42`), write 7-byte frames
   `[0x84][ADDR_HI][ADDR_LO][D3][D2][D1][D0]` to load the program into
   instruction memory, optionally preload data memory and registers, and
   set `TARGET_PC`.
3. Write `CSR = 0x00000001` to start execution.
4. Wait for the `led` pin to go high (DONE).
5. Read results back with a write of `[0x84][ADDR_HI][ADDR_LO]`, a repeated
   START, `[0x85]`, and four data bytes (MSB first).

A single 32-bit MMIO write takes 63 SCL clocks (9 for the address+ACK, 18
for the 16-bit MMIO address, 36 for the 32-bit data, all including ACKs).

Test programs are in `asm/` (assembled to `test/programs/`). `test/test.py`
and `sim/tb_regression.v` run them over the pins and check every result
against an ISA model.

## External hardware

An I2C master (e.g. a microcontroller) on `ui_in[0]` (SCL) and `uio[0]`
(SDA, open-drain, needs a pull-up if your setup doesn't already provide one).
