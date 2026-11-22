# ============================================================================
# Part 2
# ============================================================================

SEED ?= 244

VCS = $(VCS_HOME)/bin/vcs

VCS_FLAGS = -full64 \
            -sverilog \
            -timescale=1ns/1ps \
            -ntb_opts uvm \
            -debug_access+all \
            -kdb \
            -lca

SOURCES = design/controller_lab5.sv \
          design/datapath_lab5.sv \
          design/top_lab5.sv \
          tb/instr_gen_lab5.sv \
          tb/testbench_lab5.sv


# Default target
all: comp run


# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------

comp:
	$(VCS) $(VCS_FLAGS) $(SOURCES) -o simv -l comp.log


# ---------------------------------------------------------------------------
# Run with selectable random seed
# ---------------------------------------------------------------------------

run:
	./simv +ntb_random_seed=$(SEED) -l simulation.log


# ---------------------------------------------------------------------------
# Compile and run
# ---------------------------------------------------------------------------

x: comp run


# ---------------------------------------------------------------------------
# Open generated waveform in Verdi
# ---------------------------------------------------------------------------

waves:
	$(VERDI_HOME)/bin/verdi \
	-dbdir ./simv.daidir \
	-ssf lab5_part2.fsdb \
	-nologo &


# ---------------------------------------------------------------------------
# Clean simulation-generated files
# ---------------------------------------------------------------------------

clean:
	rm -rf simv \
	       simv.daidir \
	       csrc \
	       ucli.key \
	       vc_hdrs.h \
	       *.log \
	       *.fsdb \
	       verdiLog