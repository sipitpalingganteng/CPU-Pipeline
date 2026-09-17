# fibonacci.s - store fib(0..9) into data memory
#
# Iterative Fibonacci: a = fib(i), b = fib(i+1). Each result is stored at
# data address i*4. No branch delay slot, so a nop follows every branch/jump.
#
#   t0 = a, t1 = b, t2 = i, t3 = count (10), t4 = base (0)
#   t5 = compare result, t6 = &out[i], t7 = next

    .set noreorder
    .text
    .globl main

main:
    addiu $t0, $zero, 0        # a = fib(0) = 0
    addiu $t1, $zero, 1        # b = fib(1) = 1
    addiu $t2, $zero, 0        # i = 0
    addiu $t3, $zero, 10       # count = 10
    addiu $t4, $zero, 0        # base = 0
loop:
    slt   $t5, $t2, $t3        # i < count ?
    beq   $t5, $zero, done
    nop
    sll   $t6, $t2, 2          # i * 4
    addu  $t6, $t6, $t4        # &out[i]
    sw    $t0, 0($t6)          # out[i] = a
    addu  $t7, $t0, $t1        # next = a + b
    addu  $t0, $t1, $zero      # a = b
    addu  $t1, $t7, $zero      # b = next
    addiu $t2, $t2, 1          # i++
    j     loop
    nop
done:
    addiu $t5, $zero, 1        # completion flag = 1
    addiu $t6, $zero, 0x100    # flag address
    sw    $t5, 0($t6)
halt:
    j     halt
    nop
