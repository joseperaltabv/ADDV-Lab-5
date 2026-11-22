# Part 4: code coverage (line, condition, FSM, toggle) on top of Part 3
#
#   make comp               compile
#   make run SEED=244       one program, coverage in cov/seed_244.vdb
#   make report_first       text report of that one run in urg_first/
#   make regress            one program per seed in SEEDS
#   make merge              merge every cov/*.vdb into merged_coverage.vdb
#   make cov                open the merged coverage in Verdi
#   make cov_first          open the coverage of the first run (SEED) in Verdi

SEED  ?= 244
SEEDS ?= 244 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19

VCS = $(VCS_HOME)/bin/vcs

# Code coverage: which kinds to collect, and only inside the processor.
CM = -cm line+cond+fsm+tgl -cm_hier cm_hier.cfg

# The compile writes the structure of the design to simv.vdb. Each run writes
# only its own results to cov/seed_N.vdb. Reports need both.
DESIGN_DB = simv.vdb

VCS_FLAGS = -full64 \
            -sverilog \
            -timescale=1ns/1ps \
            -ntb_opts uvm \
            -debug_access+all \
            -kdb \
            -lca

# Order matters: each file uses what the ones before it define.
SOURCES = design/controller_lab5.sv \
          design/datapath_lab5.sv \
          design/top_lab5.sv \
          tb/instr_gen_lab5.sv \
          tb/fetch_if.sv \
          tb/monitor.sv \
          tb/coverage_collector.sv \
          tb/env.sv \
          tb/test.sv \
          tb/testbench_lab5.sv

# The targets are commands, not files. Without this, "make cov" does nothing
# once the cov/ directory exists.
.PHONY: comp run report_first regress merge cov cov_first waves clean

comp:
	$(VCS) $(VCS_FLAGS) $(CM) $(SOURCES) -o simv -l comp.log

run:
	./simv +ntb_random_seed=$(SEED) -cm line+cond+fsm+tgl -cm_dir cov/seed_$(SEED).vdb -l simulation.log

report_first:
	$(VCS_HOME)/bin/urg -dir $(DESIGN_DB) cov/seed_$(SEED).vdb -format text -report urg_first

regress:
	mkdir -p log
	for s in $(SEEDS); do \
		./simv +ntb_random_seed=$$s -cm line+cond+fsm+tgl -cm_dir cov/seed_$$s.vdb -l log/seed_$$s.log > /dev/null; \
	done

merge:
	$(VCS_HOME)/bin/urg -dir $(DESIGN_DB) cov/*.vdb -dbname merged_coverage.vdb -format text -report urg_merged

cov:
	$(VERDI_HOME)/bin/verdi -cov -covdir merged_coverage.vdb &

cov_first:
	$(VERDI_HOME)/bin/verdi -cov -covdir $(DESIGN_DB) -covdir cov/seed_$(SEED).vdb &

waves:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -ssf lab5_part3.fsdb -nologo &

clean:
	rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h *.log log *.fsdb verdiLog \
	       cov merged_coverage.vdb urg_merged urg_first urgReport novas* vdCovLog
