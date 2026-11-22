"""Compares the trace of the ISS with the trace of the RTL for one program.

Both traces are reduced to the same form before they are compared:
  steps   one entry per executed instruction: its PC and the 32 register
          values after it
  memory  the final value of data addresses 0, 4, 8 and 12

usage: compare_traces.py iss_trace.txt rtl_trace.txt
"""
import ast
import re
import sys

ISS_DATA_BASE = 0x10010000      # where the ISS keeps its data; everything below is program text
DATA_ADDRESSES = [0, 4, 8, 12]
MASK = 0xFFFFFFFF               # the ISS uses unbounded Python integers, the RTL 32 bits

# The ISS starts with every register at zero. The RTL register file has no
# reset, so a register that was never written reads as unknown (x) there.
# An unknown RTL register is accepted only where the ISS still has zero.
UNKNOWN = None


def read_iss(path):
    steps, memory, data_end, pc, text_base = [], {}, None, None, None
    in_final_memory = False
    for line in open(path):
        line = line.strip()
        if line.startswith('Memory: '):
            initial = ast.literal_eval(line[len('Memory: '):].strip())
            data_end = max(initial) + 4
        elif line.startswith('Executing at '):
            pc = int(line.split()[2].rstrip(':'), 16)
            # The ISS does not start at a fixed address (it starts where its
            # assembler stopped counting). The RTL starts at 0.
            if text_base is None:
                text_base = pc
            pc -= text_base
        elif line.startswith('$zero: '):
            registers = [int(field.split(': ')[1]) & MASK for field in line.split(' | ')]
            steps.append((pc, registers))
        elif line == 'Memory values:':
            in_final_memory = True
        elif in_final_memory:
            address, value = line.split(': ')
            address = int(address, 16)
            if address >= ISS_DATA_BASE:
                # a data word: the ISS address (end of data - N) is RTL address N
                memory[data_end - address] = int(value) & MASK
    return steps, [memory.get(a, 0) for a in DATA_ADDRESSES]


def rtl_value(text):
    return UNKNOWN if 'x' in text.lower() else int(text, 16)


def read_rtl(path):
    steps, memory = [], {}
    for line in open(path):
        match = re.match(r'PC=(\w+) REGS=(.*)', line)
        if match:
            steps.append((rtl_value(match.group(1)), [rtl_value(v) for v in match.group(2).split()]))
        match = re.match(r'MEM\[(\w+)\]=(\w+)', line)
        if match:
            memory[int(match.group(1), 16)] = rtl_value(match.group(2))
    return steps, [memory.get(a) for a in DATA_ADDRESSES]


def first_mismatch(iss, rtl):
    iss_steps, iss_memory = iss
    rtl_steps, rtl_memory = rtl
    for n, (i, r) in enumerate(zip(iss_steps, rtl_steps)):
        if i[0] != r[0]:
            return 'instruction %d: PC is 0x%x in the ISS and %s in the RTL' % (
                n, i[0], 'unknown' if r[0] is UNKNOWN else '0x%x' % r[0])
        for reg in range(32):
            expected, actual = i[1][reg], r[1][reg]
            if actual is UNKNOWN and expected == 0:
                continue
            if expected != actual:
                return 'instruction %d at PC 0x%x: register %d is 0x%08x in the ISS and %s in the RTL' % (
                    n, i[0], reg, expected, 'unknown' if actual is UNKNOWN else '0x%08x' % actual)
    if len(iss_steps) != len(rtl_steps):
        return 'the ISS executed %d instructions and the RTL %d' % (len(iss_steps), len(rtl_steps))
    for address, i, r in zip(DATA_ADDRESSES, iss_memory, rtl_memory):
        if i != r:
            return 'final memory at address %d is 0x%08x in the ISS and %s in the RTL' % (
                address, i, 'unknown' if r is UNKNOWN else '0x%08x' % r)
    return None


iss = read_iss(sys.argv[1])
rtl = read_rtl(sys.argv[2])
problem = first_mismatch(iss, rtl)

if problem:
    print('FAIL  %s' % problem)
    sys.exit(1)
print('PASS  %d instructions, 32 registers after each, 4 memory words' % len(iss[0]))
