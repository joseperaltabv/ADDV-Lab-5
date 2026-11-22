## Part 3: Functional Coverage

## Overview

Part 3 adds a UVM monitor and a UVM coverage collector to the Part 2 testbench.

The constrained-random instruction generator from Part 2 still creates the program and the testbench still loads it into the instruction memory. The monitor watches the instruction fetch interface of the processor and creates one instruction transaction for every instruction the processor executes. The coverage collector receives those transactions and samples the functional coverage model.

## File Descriptions

### design/controller_lab5.sv, design/datapath_lab5.sv, design/top_lab5.sv

The five-stage pipelined MIPS processor. Same files as Part 2.

### tb/instr_gen_lab5.sv

The constrained-random instruction generator. Same file as Part 2.

### tb/fetch_if.sv

The interface watched by the monitor: clock, reset, PC, fetched instruction, and a branch-taken signal.

### tb/monitor.sv

`instr_monitor`, extends `uvm_monitor`.

- Samples the fetch interface once per clock cycle
- Counts a stalled instruction once
- Does not report an instruction that is flushed by a taken branch
- Marks each BEQ as taken or not taken from what the processor did
- Posts each instruction transaction to a `uvm_analysis_port`

### tb/coverage_collector.sv

`coverage_collector`, extends `uvm_subscriber`.

It contains three covergroups:

- `instr_fields_cg`: instruction kind, rs, rt, rd, memory address, branch offset, branch taken / not taken
- `register_dependency_cg`: producer and consumer kind, the register that carries the dependency, and the gap (1 to 4)
- `memory_dependency_cg`: the address of a store followed by a load, and the gap (1 to 4)

### tb/env.sv

`instr_env`, extends `uvm_env`. Creates the monitor and the coverage collector and connects them.

### tb/test.sv

`instr_test`, extends `uvm_test`. Creates the environment.

### tb/testbench_lab5.sv

The Part 2 testbench with three additions:

- An instance of `fetch_if` connected to the processor
- Registration of the interface for the monitor
- `run_test("instr_test")` at time 0

The end-of-simulation trickbox is unchanged: a store of 0xDEADBEEF to address 0x0000000C ends the simulation.

### generated/generated_program.mem

An example program produced with seed 244.

### Makefile

Commands for compiling, running one seed, running many seeds, merging the coverage databases, and opening the coverage in Verdi.

## Compile

make clean
make comp

## Run one program

make run SEED=244

The coverage database is written to cov/seed_244.vdb.

## Run many programs and merge the coverage

make regress
make merge

`make regress` runs one program for every seed in SEEDS (20 seeds by default). `make merge` merges every database under cov/ into merged_coverage.vdb.

## Open the coverage in Verdi

make cov_first SEED=244
make cov

`make cov_first` opens the coverage of one run. `make cov` opens the merged coverage.
