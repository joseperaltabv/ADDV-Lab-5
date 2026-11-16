## Part 1: Verification Plan

## Overview

Part 1 contains the verification plan for the five-stage pipelined MIPS processor.

## Verification Scope

The verification plan needs the following requirements:

- Instructions: ADD, AND, LW, SW, BEQ
- Registers: $1, $2, $3, $4
- Data memory addresses:
  - 0x00000000
  - 0x00000004
  - 0x00000008
  - 0x0000000C
- Dependency gaps: 1, 2, 3, and 4 instructions
- BEQ offsets: 1, 2, 3, and 4

## Verification Plan

The verification plan includes:

### 1. Testbench Architecture
Includes:

- Instruction Generator
- Instruction Loader / Program Loader
- Pipelined MIPS DUT
- Instruction Fetch Monitor
- Coverage Collector
- Instruction Set Simulator (ISS)
- Trace Comparator

### 2. Stimulus
The stimulus methodology uses constrained-random generation to produce valid instruction streams using ADD, AND, LW, SW, and BEQ.

Includes:

- Random individual instructions
- Register-dependent instruction pairs
- Memory-dependent SW/LW pairs
- Dependency gaps of 1-4 instructions
- BEQ taken and not-taken scenarios
- BEQ offsets of 1-4

### 3. Functional Coverage
Includes:

- Instruction type
- Register usage
- Data-memory addresses
- BEQ taken and not taken
- BEQ offsets
- Register dependencies
- Memory dependencies
- Dependency gaps

### 4. Checking
The same instruction program will be executed by both the RTL MIPS processor and an ISS.

The RTL execution trace will be compared against the ISS reference trace.

Include:

- Register write-back values
- Memory store address and data
- Memory load values
- BEQ behavior and target address
- Overall RTL trace versus ISS trace
