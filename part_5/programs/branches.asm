# Program 3: one branch that is not taken and two that are taken.
# $at = $1, $v0 = $2, $v1 = $3, $a0 = $4
.data
at_12: .word 3735928559
at_8: .word 15
at_4: .word 3
.text
lw $at, 4($zero)
lw $v0, 8($zero)
beq $at, $v0, far
add $v1, $at, $at
and $a0, $v1, $v0
beq $v1, $a0, skip
add $v1, $v1, $v1
add $a0, $a0, $a0
skip:
add $at, $v1, $a0
beq $at, $at, near
and $v0, $v0, $at
near:
sw $at, 4($zero)
far:
# end of simulation: store 0xDEADBEEF to address 12
lw $a0, 12($zero)
sw $a0, 12($zero)
