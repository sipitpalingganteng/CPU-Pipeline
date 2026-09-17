# bubble_sort.s - bubble sort an 8-word array in data memory (ascending)
#
# The array lives at data addresses 0..28 and is preloaded by the testbench.
# The CPU has no branch delay slot (the instruction after a branch/jump is
# flushed), so a nop is placed after each branch/jump.
#
#   t0 = base address (0)
#   t1 = n (8)
#   t9 = pass counter
#   t2 = i, t3 = n-1-pass, t4 = compare result
#   t5 = &a[i], t6 = a[i], t7 = a[i+1], t8 = swap flag

    .set noreorder
    .text
    .globl main

main:
    addiu $t0, $zero, 0        # base = 0
    addiu $t1, $zero, 8        # n = 8
    addiu $t9, $zero, 0        # pass = 0
outer:
    slt   $t4, $t9, $t1        # pass < n ?
    beq   $t4, $zero, done
    nop
    addiu $t2, $zero, 0        # i = 0
    addiu $t3, $t1, -1         # n - 1
    subu  $t3, $t3, $t9        # n - 1 - pass
outer_cond:
    slt   $t4, $t2, $t3        # i < n-1-pass ?
    beq   $t4, $zero, next_pass
    nop
inner:
    sll   $t5, $t2, 2          # i * 4
    addu  $t5, $t5, $t0        # &a[i]
    lw    $t6, 0($t5)          # a[i]
    lw    $t7, 4($t5)          # a[i+1]
    slt   $t8, $t7, $t6        # a[i+1] < a[i] ?
    beq   $t8, $zero, no_swap
    nop
    sw    $t7, 0($t5)          # swap
    sw    $t6, 4($t5)
no_swap:
    addiu $t2, $t2, 1          # i++
    j     outer_cond
    nop
next_pass:
    addiu $t9, $t9, 1          # pass++
    j     outer
    nop
done:
    addiu $t0, $zero, 1        # completion flag = 1
    addiu $t5, $zero, 0x100    # flag address
    sw    $t0, 0($t5)
halt:
    j     halt
    nop
