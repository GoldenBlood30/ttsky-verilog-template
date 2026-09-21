"""
Tiny Tapeout required cocotb test.

This drives the design through its ACTUAL fabricated pins (ui_in/uio_*),
the same way the Vivado/Icarus testbenches in this project did, just in
cocotb's Python style since that's what Tiny Tapeout's CI gate requires.

This is a representative subset, not the full exhaustive test suite --
enough to satisfy Tiny Tapeout's automated check and prove basic
reset + I2C-load + run + halt correctness. Expand it with more of the
programs/checks from the Icarus master testbench if you want deeper local
coverage; TT's CI only requires this file to pass, it doesn't require full
exhaustiveness.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

SDA_BIT = 0   # uio[0]
SCL_BIT = 0   # ui_in[0]


class I2CDriver:
    """Models the open-drain SDA bus: two independent drivers (this 'MCU'
    model and the DUT itself via uio_oe/uio_out) resolved the same way a
    real pull-up resistor resolves a shared open-drain line."""

    def __init__(self, dut):
        self.dut = dut
        self.mcu_release = True
        cocotb.start_soon(self._resolve_loop())

    async def _resolve_loop(self):
        while True:
            await Timer(10, unit="ns")
            dut_oe = (int(self.dut.uio_oe.value) >> SDA_BIT) & 1
            bus_high = self.mcu_release and not dut_oe
            val = int(self.dut.uio_in.value)
            if bus_high:
                val |= (1 << SDA_BIT)
            else:
                val &= ~(1 << SDA_BIT)
            self.dut.uio_in.value = val

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
        await Timer(5000, unit="ns")
        self.mcu_release = False
        await Timer(5000, unit="ns")
        self.set_scl(0)
        await Timer(5000, unit="ns")

    async def stop(self):
        self.mcu_release = False
        self.set_scl(0)
        await Timer(5000, unit="ns")
        self.set_scl(1)
        await Timer(5000, unit="ns")
        self.mcu_release = True
        await Timer(5000, unit="ns")

    async def write_bit(self, b):
        self.set_scl(0)
        self.mcu_release = bool(b)
        await Timer(5000, unit="ns")
        self.set_scl(1)
        await Timer(5000, unit="ns")

    async def ack_bit(self):
        self.set_scl(0)
        self.mcu_release = True
        await Timer(5000, unit="ns")
        self.set_scl(1)
        await Timer(5000, unit="ns")
        self.set_scl(0)
        await Timer(5000, unit="ns")

    async def write_byte(self, byte_val):
        for k in range(7, -1, -1):
            await self.write_bit((byte_val >> k) & 1)
        await self.ack_bit()

    async def mmio_write(self, addr, data):
        await self.start()
        await self.write_byte(0x84)  # 0x42 << 1 | write
        await self.write_byte((addr >> 8) & 0xFF)
        await self.write_byte(addr & 0xFF)
        await self.write_byte((data >> 24) & 0xFF)
        await self.write_byte((data >> 16) & 0xFF)
        await self.write_byte((data >> 8) & 0xFF)
        await self.write_byte(data & 0xFF)
        await self.stop()
        await Timer(100, unit="ns")


async def reset(dut):
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 1  # scl idle high
    dut.uio_in.value = 0
    await Timer(100, unit="ns")
    dut.rst_n.value = 1
    await Timer(100, unit="ns")


@cocotb.test()
async def test_reset_sanity(dut):
    """After reset: PC=0, done=0, run_req=0, R0=0 -- checked via the same
    hierarchy paths used throughout this project's Icarus testbenches."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    assert int(dut.top_inst.PC_out.value) == 0, "PC should be 0 after reset"
    assert int(dut.top_inst.done.value) == 0, "done should be 0 after reset"
    assert int(dut.top_inst.run_req.value) == 0, "run_req should be 0 after reset"
    assert int(dut.top_inst.REGFILE_inst.RF[0].value) == 0, "R0 should be 0 after reset"
    assert int(dut.uo_out.value) == 0, "led should be 0 after reset"


@cocotb.test()
async def test_load_run_halt(dut):
    """End-to-end: load a tiny 2-instruction program via real I2C pins,
    run it, and confirm the correct result -- proving the wrapper's pin
    remapping and the whole pipeline work together through the actual
    fabricated interface, not just the internal RTL."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    i2c = I2CDriver(dut)

    # ADDI R1,$0,5   -> R1 = 5
    # SW   R1,0($0)  -> DM[0] = 5
    await i2c.mmio_write(0x0000, 0x08010005)
    await i2c.mmio_write(0x0004, 0x10010000)
    await i2c.mmio_write(0x3004, 0x00000008)  # target_pc
    await i2c.mmio_write(0x3000, 0x00000001)  # RUN=1

    max_cycles = 2000
    n = 0
    while int(dut.top_inst.done.value) == 0 and n < max_cycles:
        await RisingEdge(dut.clk)
        n += 1

    assert int(dut.top_inst.done.value) == 1, f"done never asserted within {max_cycles} cycles"
    assert int(dut.top_inst.REGFILE_inst.RF[1].value) == 5, "R1 should be 5"
    assert int(dut.top_inst.DM_inst.DM[0].value) == 5, "DM[0] should be 5"
    assert int(dut.uo_out.value) & 1 == 1, "led should be high once done"
