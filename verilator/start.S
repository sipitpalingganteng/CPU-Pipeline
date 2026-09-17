// Startup stub for the pipeline_cpu C runtime.
//
// The CPU resets to 0xbfc00000, so _start must be the first instruction.
// It sets up a stack in data RAM (which grows down from 0x7f00, clear of the
// framebuffer at 0x10000), calls main, then spins.
//
// The CPU flushes the instruction after a taken branch and links jal to
// PC + 4, so the explicit nops below are required with .set noreorder.

    .set noreorder
    .set noat
    .text
    .globl _start
_start:
    addiu $sp, $zero, 0x7f00
    jal   main
    nop
1:  j     1b
    nop
