# Program 1: register dependencies between ADD and AND at gaps 0, 1 and 2.
# $at = $1, $v0 = $2, $v1 = $3, $a0 = $4
.data
at_12: .word 3735928559
at_8: .word 15
at_4: .word 3
.text
lw $at, 4($zero)
lw $v0, 8($zero)
add $v1, $at, $v0
and $a0, $v1, $v0
add $at, $v1, $a0
and $v0, $v1, $at
add $v1, $v0, $v0
add $a0, $at, $at
and $at, $v1, $a0
add $v0, $a0, $v1
sw $v0, 8($zero)
# end of simulation: store 0xDEADBEEF to address 12
lw $a0, 12($zero)
sw $a0, 12($zero)
