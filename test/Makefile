# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
PYTHON ?= python3
SRC_DIR = $(PWD)/../src

# Prefer PDK_ROOT from environment; if missing, derive it from the run config.
PDK_ROOT ?= $(shell sed -n 's/.*"PDK_ROOT"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' $(PWD)/../runs/wokwi/resolved.json | head -n 1)

# Resolve cocotb makefiles through the selected Python interpreter.
COCOTB_MAKEFILES := $(shell $(PYTHON) -c "import cocotb, os; print(os.path.join(os.path.dirname(cocotb.__file__), 'share', 'makefiles'))")
# List of source files (relative to src/) — keep in sync with info.yaml
PROJECT_SOURCES = tt_um_AmitChen1415.v \
				  blackjack_core.v \
				  pwrup_synchronizer.v \
				  rng_card.v \
				  vga_controller.v\
				  blackjack_table.v\
				  

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

ifeq ($(strip $(PDK_ROOT)),)
$(error PDK_ROOT is not set. Export PDK_ROOT or ensure runs/wokwi/resolved.json contains a PDK_ROOT entry)
endif

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(COCOTB_MAKEFILES)/Makefile.sim
