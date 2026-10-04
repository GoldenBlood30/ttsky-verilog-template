"""
Tiny Tapeout cocotb test for the reprogrammable custom RISC-V core.

Everything is driven and checked through the chip's pins only (I2C on
ui_in[0]/uio[0], the DONE LED on uo_out[0]), never through internal signals,
so the same test runs on the RTL and on the gate-level netlist (GATES=yes,
used by the gl_test CI job).

Each program in programs/ (assembled from ../asm) is loaded over I2C, run to
DONE, and every result is compared with a small ISA model below: the
registers the program writes, all of DMEM, the CSR (RUN, DONE and the six ALU
flags) and the final PC.

Register/IMEM/DMEM readback is only used while the core is halted (RUN=0 or
DONE=1): the readback shares the CPU's read ports.
"""

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, ValueChange

SDA_BIT = 0   # uio[0]
SCL_BIT = 0   # ui_in[0]
HALF = 1000   # ns per SCL half-period (100 clk cycles at 10 ns clk)

A_IMEM, A_REG, A_DMEM = 0x0000, 0x1000, 0x2000
A_CSR, A_TARGET, A_PC = 0x3000, 0x3004, 0x3008
UNMAPPED = 0x0DEADBEE
NOP = 0xFC000000
MASK32 = 0xFFFFFFFF

PROG_DIR = Path(__file__).resolve().parent / "programs"
# fill_<IMW> is added at run time, once the IMEM size is known
PROGRAMS = ["tt_test", "flags_test", "fwd_stall", "ldst", "branches",
            "mul", "fib", "fact", "div", "div0", "fill"]


# ---------------------------------------------------------------------------
# I2C master, bit-banged on the pins
# ---------------------------------------------------------------------------
class I2CDriver:
    """Models the open-drain SDA bus: two independent drivers (this 'MCU'
    model and the DUT itself via uio_oe/uio_out) resolved the same way a
    real pull-up resistor resolves a shared open-drain line."""

    def __init__(self, dut):
        self.dut = dut
        self._release = True
        cocotb.start_soon(self._resolve_loop())

    # mcu_release is a property so that every change re-resolves the bus
    # immediately (like a setter function that also updates the pin).
    @property
    def mcu_release(self):
        return self._release

    @mcu_release.setter
    def mcu_release(self, level):
        self._release = level
        self._resolve()

    def _resolve(self):
        dut_oe = (int(self.dut.uio_oe.value) >> SDA_BIT) & 1
        bus_high = self._release and not dut_oe
        # Only uio[0] is used; the other uio inputs stay 0. (Writing the whole
        # byte avoids reading back a value written earlier in the same step.)
        self.dut.uio_in.value = (1 << SDA_BIT) if bus_high else 0

    async def _resolve_loop(self):
        # Event-driven, not polled: wake only when the DUT changes its SDA
        # driver. Polling every few ns makes the gate-level run very slow.
        while True:
            self._resolve()
            await ValueChange(self.dut.uio_oe)

    def set_scl(self, level):
        val = int(self.dut.ui_in.value)
        if level:
            val |= (1 << SCL_BIT)
        else:
            val &= ~(1 << SCL_BIT)
        self.dut.ui_in.value = val

    async def start(self):
        self.mcu_release = True
        self.set_scl(1)
        await Timer(HALF, unit="ns")
        self.mcu_release = False
        await Timer(HALF, unit="ns")
        self.set_scl(0)
        await Timer(HALF, unit="ns")

    async def stop(self):
        self.mcu_release = False
        self.set_scl(0)
        await Timer(HALF, unit="ns")
        self.set_scl(1)
        await Timer(HALF, unit="ns")
        self.mcu_release = True
        await Timer(HALF, unit="ns")

    async def write_bit(self, b):
        self.set_scl(0)
        self.mcu_release = bool(b)
        await Timer(HALF, unit="ns")
        self.set_scl(1)
        await Timer(HALF, unit="ns")

    async def ack_bit(self):
        self.set_scl(0)
        self.mcu_release = True
        await Timer(HALF, unit="ns")
        self.set_scl(1)
        await Timer(HALF, unit="ns")
        self.set_scl(0)
        await Timer(HALF, unit="ns")

    async def write_byte(self, byte_val):
        for k in range(7, -1, -1):
            await self.write_bit((byte_val >> k) & 1)
        await self.ack_bit()

    async def read_byte(self, ack):
        val = 0
        for _ in range(8):
            self.set_scl(0)
            self.mcu_release = True
            await Timer(HALF, unit="ns")
            self.set_scl(1)
            await Timer(HALF, unit="ns")
            val = (val << 1) | ((int(self.dut.uio_in.value) >> SDA_BIT) & 1)
        self.set_scl(0)
        self.mcu_release = not ack   # ACK = pull low, NACK = release
        await Timer(HALF, unit="ns")
        self.set_scl(1)
        await Timer(HALF, unit="ns")
        return val

    async def mmio_write(self, addr, data):
        await self.start()
        await self.write_byte(0x84)  # 0x42 << 1 | write
        await self.write_byte((addr >> 8) & 0xFF)
        await self.write_byte(addr & 0xFF)
        for shift in (24, 16, 8, 0):
            await self.write_byte((data >> shift) & 0xFF)
        await self.stop()
        await Timer(100, unit="ns")

    async def mmio_read(self, addr):
        await self.start()
        await self.write_byte(0x84)  # 0x42 << 1 | write
        await self.write_byte((addr >> 8) & 0xFF)
        await self.write_byte(addr & 0xFF)
        await self.start()           # repeated START
        await self.write_byte(0x85)  # 0x42 << 1 | read
        val = 0
        for i in range(4):
            val = (val << 8) | await self.read_byte(ack=(i < 3))
        await self.stop()
        await Timer(100, unit="ns")
        return val


async def setup(dut):
    """Start the clock, pulse reset, return an I2C master."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.ena.value = 1
    dut.ui_in.value = 1  # scl idle high
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await Timer(100, unit="ns")
    dut.rst_n.value = 1
    await Timer(100, unit="ns")
    return I2CDriver(dut)


async def memory_sizes(i2c):
    """IMEM/DMEM depth in words, found through the pins: the first word
    address past the end of a memory reads back as UNMAPPED. IMEM has no
    reset (an unwritten word reads as X in simulation, garbage on silicon),
    so each probed IMEM word is written first; programs never run past
    their own length, so the marker is harmless. DMEM resets to 0, so it is
    probed read-only (a marker there would show up in the results)."""
    sizes = []
    for base, candidates in ((A_IMEM, (16, 32, 64, 128, 256)), (A_DMEM, (8, 16, 32, 64))):
        for n in candidates:
            if base == A_IMEM:
                await i2c.mmio_write(base + 4 * n, 0x600DC0DE)   # ignored if unmapped
            if await i2c.mmio_read(base + 4 * n) == UNMAPPED:
                sizes.append(n)
                break
        else:
            raise AssertionError(f"no unmapped word found past {base:#06x}")
    return sizes[0], sizes[1]


# ---------------------------------------------------------------------------
# ISA model (same rules as sim/tb_regression.v's model_run)
# ---------------------------------------------------------------------------
def alu_flags(sub, a, b):
    """{AF,PF,OF,SF,CF,ZF} as the 6-bit value that lands in CSR[7:2]."""
    if sub:
        wide = a - b                       # negative -> borrow
        r = wide & MASK32
        cf = 1 if wide < 0 else 0
    else:
        wide = a + b
        r = wide & MASK32
        cf = wide >> 32                    # carry out of bit 31
    def signed(x):                         # 32-bit two's complement -> Python int
        return x - (1 << 32) if x & 0x80000000 else x
    exact = signed(a) - signed(b) if sub else signed(a) + signed(b)
    of = 1 if exact != signed(r) else 0    # result doesn't fit in int32
    af = ((a ^ b ^ r) >> 4) & 1            # carry/borrow into bit 4
    pf = 1 if bin(r & 0xFF).count("1") % 2 == 0 else 0
    sf = r >> 31
    zf = 1 if r == 0 else 0
    return (af << 5) | (pf << 4) | (of << 3) | (sf << 2) | (cf << 1) | zf


def run_model(prog, dm_init, dmw, max_steps=20000):
    """Executes prog (list of words) until PC reaches len(prog) (TARGET_PC).
    Returns registers, DMEM, flags, the registers it wrote, and the
    registers it read before writing them (the test preloads those)."""
    rf = [0] * 32
    dm = list(dm_init)
    flags = 0
    written, read_first = set(), set()
    pc, steps = 0, 0
    while pc != len(prog):
        assert 0 <= pc < len(prog) and steps < max_steps, "model: program runs away"
        ins = prog[pc]
        op, rs, rt, rd = ins >> 26, (ins >> 21) & 31, (ins >> 16) & 31, (ins >> 11) & 31
        imm = ins & 0xFFFF
        imm = (imm - 0x10000 if imm & 0x8000 else imm) & MASK32   # sign-extend
        for r in ((rs, rt) if op in (0, 1, 4, 5) else (rs,) if op in (2, 3) else ()):
            if r != 0 and r not in written:
                read_first.add(r)
        a, b = rf[rs], rf[rt]
        nxt = pc + 1
        dest, val = None, None
        if op == 0:   # add
            flags, dest, val = alu_flags(0, a, b), rd, (a + b) & MASK32
        elif op == 1: # sub
            flags, dest, val = alu_flags(1, a, b), rd, (a - b) & MASK32
        elif op == 2: # addi
            flags, dest, val = alu_flags(0, a, imm), rt, (a + imm) & MASK32
        elif op == 3: # lw (word address, low DM_AW bits)
            dest, val = rt, dm[(a + imm) & (dmw - 1)]
        elif op == 4: # sw
            dm[(a + imm) & (dmw - 1)] = b
        elif op == 5: # beq: flags of rs - rt, offset in words from PC+1
            flags = alu_flags(1, a, b)
            if a == b:
                nxt = (pc + 1 + (imm - (1 << 32) if imm & 0x80000000 else imm))
        # anything else (0xFC000000 NOP, unused opcodes) does nothing
        if dest:      # r0 is never written
            rf[dest] = val
            written.add(dest)
        pc = nxt
        steps += 1
    return rf, dm, flags, written, read_first, steps


def load_program(name):
    def words(path):
        text = path.read_text().split() if path.exists() else []
        return [int(w, 16) for w in text]
    return words(PROG_DIR / f"{name}_instr.hex"), words(PROG_DIR / f"{name}_data.hex")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset_and_readback(dut):
    """Reset state, unmapped reads, and write/readback of the first and last
    word of every region while halted."""
    i2c = await setup(dut)
    imw, dmw = await memory_sizes(i2c)
    dut._log.info(f"IMEM {imw} words, DMEM {dmw} words")

    assert int(dut.uo_out.value) == 0, "led should be 0 after reset"
    assert await i2c.mmio_read(A_CSR) == 0, "CSR should be 0 after reset"
    assert await i2c.mmio_read(A_PC) == 0, "PC should be 0 after reset"
    assert await i2c.mmio_read(A_REG) == 0, "r0 should read 0"
    for addr in (A_REG + 4 * 32, 0x300C, 0x4000, 0xFFFC):
        got = await i2c.mmio_read(addr)
        assert got == UNMAPPED, f"unmapped {addr:#06x}: got {got:#010x}"

    for addr, data in [(A_IMEM, 0x12345678), (A_IMEM + 4 * (imw - 1), 0xCAFEF00D),
                       (A_REG + 4, 0x5A5A5A5A), (A_REG + 4 * 31, 0xA5A5A5A5),
                       (A_DMEM, 0x0BADF00D), (A_DMEM + 4 * (dmw - 1), 0x8BADF00D),
                       (A_TARGET, 0x00000020)]:
        await i2c.mmio_write(addr, data)
        got = await i2c.mmio_read(addr)
        assert got == data, f"readback {addr:#06x}: got {got:#010x}, want {data:#010x}"

    await i2c.mmio_write(A_REG, 0xFFFFFFFF)
    assert await i2c.mmio_read(A_REG) == 0, "r0 must stay 0"
    await i2c.mmio_write(A_CSR, 0xFFFFFFFE)      # only RUN (bit 0) is writable
    assert await i2c.mmio_read(A_CSR) == 0, "CSR bits 1-7 must be read-only"


@cocotb.test()
@cocotb.parametrize(name=PROGRAMS)
async def test_program(dut, name):
    """Load one assembly program over I2C, run it to DONE, compare all
    results with the ISA model."""
    i2c = await setup(dut)
    imw, dmw = await memory_sizes(i2c)
    if name == "fill":
        name = f"fill_{imw}"
    prog, data = load_program(name)
    assert 3 <= len(prog) <= imw, f"{name}: {len(prog)} words does not fit IMEM ({imw})"
    dm_init = (data + [0] * dmw)[:dmw]

    # Pre-pass: which registers does the program read before writing them?
    _, _, _, written, read_first, _ = run_model(prog, dm_init, dmw)
    # Registers named as a destination but never written architecturally
    # (e.g. on a flushed wrong path) get a sentinel that must survive.
    dests = {(w >> 11) & 31 if (w >> 26) in (0, 1) else (w >> 16) & 31
             for w in prog if (w >> 26) in (0, 1, 2, 3)}
    sentinel = {r: 0x5E000000 | r for r in dests - written - read_first - {0}}
    preload = {r: 0 for r in read_first}
    preload.update(sentinel)

    rf, dm, flags, written, _, steps = run_model(prog, dm_init, dmw)
    for r, v in sentinel.items():
        rf[r] = v

    for k, w in enumerate(prog):
        await i2c.mmio_write(A_IMEM + 4 * k, w)
    for k, w in enumerate(dm_init):
        if w:
            await i2c.mmio_write(A_DMEM + 4 * k, w)
    for r, v in preload.items():
        await i2c.mmio_write(A_REG + 4 * r, v)
    await i2c.mmio_write(A_TARGET, 4 * len(prog))
    await i2c.mmio_write(A_CSR, 1)               # RUN

    for _ in range(steps * 6 + 500):             # ~6 cycles/instr worst case + drain
        if int(dut.uo_out.value) & 1:
            break
        await ClockCycles(dut.clk, 10)
    assert int(dut.uo_out.value) & 1, f"{name}: DONE (led) never went high"

    errors = []
    def check(what, got, want):
        if got != want:
            errors.append(f"{what}: got {got:#010x}, want {want:#010x}")

    check("CSR", await i2c.mmio_read(A_CSR), (flags << 2) | 0b11)
    check("PC", await i2c.mmio_read(A_PC), 4 * len(prog))
    for r in sorted(written | set(preload) | {0}):
        check(f"r{r}", await i2c.mmio_read(A_REG + 4 * r), rf[r])
    for k in range(dmw):
        check(f"DM[{k}]", await i2c.mmio_read(A_DMEM + 4 * k), dm[k])
    dut._log.info(f"{name}: {len(prog)} words, {steps} instructions, flags {flags:06b}")
    assert not errors, f"{name}:\n  " + "\n  ".join(errors)
