.text
.globl main

main:
    addiu $t0, $zero, 5       # t0 = 5
    addiu $t1, $zero, 7       # t1 = 7
    addu  $t2, $t0, $t1       # forwarding: t2 = 12
    sw    $t2, 0($zero)       # memory[0] = 12
    lw    $t3, 0($zero)       # t3 = 12
    addiu $t4, $t3, 1         # load-use stall: t4 = 13
    subu  $t5, $t4, $t0       # forwarding: t5 = 8
    and   $t6, $t5, $t2       # t6 = 8
    or    $t7, $t6, $t4       # t7 = 13
    xor   $s0, $t7, $t5       # s0 = 5
