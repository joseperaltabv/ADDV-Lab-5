# Part 5: compare the RTL against an instruction set simulator (ISS)
#
#   make            compile, then run and compare all three programs
#   make comp       compile the RTL and the testbench
#   make forwarding         run and compare one program (also: load_store, branches)
#   make waves PROGRAM=forwarding   open the waveform of the last run in Verdi

PROGRAMS = forwarding load_store branches
PROGRAM ?= forwarding

VCS = $(VCS_HOME)/bin/vcs

VCS_FLAGS = -full64 \
            -sverilog \
            -timescale=1ns/1ps \
            -debug_access+all \
            -kdb \
            -lca

SOURCES = design/controller_lab5.sv \
          design/datapath_lab5.sv \
          design/top_lab5.sv \
          tb/testbench.sv

.PHONY: all comp waves clean $(PROGRAMS)

all: comp $(PROGRAMS)

comp:
	$(VCS) $(VCS_FLAGS) $(SOURCES) -o simv -l comp.log > /dev/null

# For one program:
#   1. the ISS assembles it (output.txt) and executes it (iss_trace.txt)
#   2. the RTL runs the same machine code and writes rtl_trace.txt
#   3. the two traces are compared
# The ISS always reads input.txt and writes output.txt in the current directory.
$(PROGRAMS):
	@mkdir -p build/$@
	@cp programs/$@.asm build/$@/input.txt
	@cd build/$@ && python3 ../../iss/Mips_Simulator.py > iss_trace.txt
	@python3 scripts/dmem_init.py programs/$@.asm build/$@/dmem.hex
	@./simv +PROG=build/$@/output.txt +DMEM=build/$@/dmem.hex +TRACE=build/$@/rtl_trace.txt -l build/$@/simulation.log > /dev/null
	@printf '%-12s' $@
	@python3 scripts/compare_traces.py build/$@/iss_trace.txt build/$@/rtl_trace.txt

waves:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -ssf lab5_part5.fsdb -nologo &

clean:
	rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h *.log *.fsdb verdiLog novas* build
