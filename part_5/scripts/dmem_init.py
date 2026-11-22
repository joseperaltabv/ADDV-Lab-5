"""Writes the data memory image for the RTL from the .data section of a program.

The ISS addresses a load or store by counting back from the end of its data
section: offset N means (end of data - N). The RTL uses the offset itself as
the address. So the last .word of the program is RTL address 4, the one before
it is address 8, and so on. Address 0 has no .word and starts as zero.

usage: dmem_init.py program.asm dmem.hex
"""
import sys


def data_words(path):
    words = []
    in_data = False
    for line in open(path):
        line = line.strip()
        if line.startswith('.data'):
            in_data = True
        elif line.startswith('.text'):
            in_data = False
        elif in_data and '.word' in line:
            words += [int(v) for v in line.split('.word')[1].split(',')]
    return words


words = data_words(sys.argv[1])
image = [0] + words[::-1]

with open(sys.argv[2], 'w') as out:
    for value in image:
        out.write('%08x\n' % (value & 0xFFFFFFFF))
