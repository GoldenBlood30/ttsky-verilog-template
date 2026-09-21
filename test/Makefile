SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(shell find $(PWD)/../src -name "*.v")
TOPLEVEL = tt_um_mips_i2c
MODULE = test

include $(shell cocotb-config --makefiles)/Makefile.sim
