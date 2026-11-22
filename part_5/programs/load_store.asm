# Program 2: loads followed at once by their use, and stores followed by loads of the same address.
# $at = $1, $v0 = $2, $v1 = $3, $a0 = $4
.data
at_12: .word 3735928559
at_8: .word 15
at_4: .word 3
.text
lw $at, 4($zero)
sw $at, 0($zero)
lw $v0, 0($zero)
add $v1, $v0, $at
sw $v1, 4($zero)
lw $a0, 8($zero)
and $at, $a0, $v1
sw $at, 8($zero)
lw $v0, 4($zero)
lw $v1, 8($zero)
add $a0, $v0, $v1
sw $a0, 0($zero)
# end of simulation: store 0xDEADBEEF to address 12
lw $a0, 12($zero)
sw $a0, 12($zero)
