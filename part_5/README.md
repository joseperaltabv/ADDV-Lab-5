## Part 5: Integrating an ISS

## Overview

Part 5 checks the pipelined MIPS processor against an instruction set simulator (ISS).

The same program is run twice, separately: once on the ISS and once on the RTL. Each run writes a trace. A Python script compares the two traces. The ISS is not called from SystemVerilog.

Three hand-written programs are used. Each has at least ten instructions and uses only ADD, AND, LW, SW and BEQ.

## The ISS

iss/Mips_Simulator.py is MIPS-Simulator by viggu3sd (https://github.com/viggu3sd/MIPS-Simulator), used without changes. It reads an assembly program from input.txt, writes the machine code to output.txt, executes it one instruction at a time, and prints the PC, the instruction and all 32 registers after every instruction, and the memory at the end.

Its license is in iss/LICENSE.

## File Descriptions

### design/controller_lab5.sv, design/datapath_lab5.sv, design/top_lab5.sv

The five-stage pipelined MIPS processor. Same files as Part 2. Not changed for Part 5.

### tb/testbench.sv

Loads the machine code that the ISS assembled into the instruction memory, runs the processor, and writes the RTL trace: for every executed instruction its PC and the 32 register values after it, and at the end the four data memory words.

The simulation ends when the program stores 0xDEADBEEF to address 0x0000000C, as in Parts 2 to 4.

### programs/forwarding.asm

Register dependencies between ADD and AND at gaps 0, 1 and 2. 13 instructions.

### programs/load_store.asm

Loads followed at once by their use, and stores followed by loads of the same address. 14 instructions.

### programs/branches.asm

One branch that is not taken and two that are taken. 14 instructions, 11 executed.

### scripts/dmem_init.py

Writes the data memory image for the RTL from the .data section of a program.

### scripts/compare_traces.py

Reads the ISS trace and the RTL trace, brings both to the same form, and compares them instruction by instruction. Prints PASS, or FAIL with the first difference.

### Makefile

Compiles the RTL and runs the three programs through the ISS, the RTL and the comparison.

## Run

make

compiles and then runs and compares all three programs. One line is printed per program:

forwarding  PASS  13 instructions, 32 registers after each, 4 memory words

One program can be run by name:

make comp
make forwarding

The files of a run are in build/<program>/: input.txt (the program), output.txt (machine code from the ISS), iss_trace.txt, dmem.hex, rtl_trace.txt.

## Differences between the ISS and the RTL that the comparison accounts for

- The ISS uses the register names $at, $v0, $v1, $a0 for registers 1 to 4.
- The ISS does not start at address 0. The comparison uses the PC relative to the first instruction.
- The ISS ignores the base register of LW and SW and addresses data as (end of the data section - offset). The programs always use $zero as the base, and the comparison maps the ISS address back to the offset, which is the RTL address.
- The ISS uses unbounded integers. Register and memory values are cut to 32 bits before they are compared.
- The ISS starts with all registers at zero. The RTL register file has no reset, so a register that was never written is unknown. An unknown RTL register is accepted only where the ISS has zero.
