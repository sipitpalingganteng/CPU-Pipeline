Bug found and fixed
rtl/mips_pipeline.v resolved branches in ID and flushed the following instruction (no delay slot — tb_branch_cpu.v confirms), but jal linked $ra = PC + 8. Returning from a subroutine skipped an instruction, so subroutines were unusable. Changed the link constant to PC + 4 (src2_is_8 → src2_is_4) and added sim/tb_jal_cpu.v as a regression test. tb_branch_cpu, tb_pipeline_cpu, and the new test all PASS.
New files
- verilator/sim_main.cpp — Verilator harness modelling the CPU's instruction/data SRAM ports and memory-mapping a framebuffer, input register, cycle counter, and frame-done handshake to raylib.
- verilator/pong.asm — MIPS pong: player paddle (W/S or arrows), ball physics with wall/paddle bounces and angle off the hit position, AI opponent, pseudo-random serves.
- verilator/assembler.py — assembler for the CPU's instruction subset (addu…jr, addiu, lui, lw/sw, beq/bne, jal) plus .eqv constants and nop/move/b/li/la.
- verilator/Makefile — builds the hex and the Verilator+raylib binary.
Memory map
0x00000000 RAM · 0x00010000 64×32 framebuffer · 0x00020000 input · 0x00020004 counter · 0x00020008 frame-done.
Run
cd verilator && make && make run
The CPU runs one game frame per rendered 60 Hz frame (~41k cycles/frame), then the framebuffer is uploaded as a point-filtered texture scaled 14×. Verified headless over 250 frames (ball bounces, paddles move/clamp, AI tracks, serves reset) and confirmed the raylib window initializes on your OpenGL device.
One caveat: sim_main.cpp uses top->inst_sram_rdata/data_sram_rdata combinationally, matching the testbenches' assumption of combinational SRAM. If you later add a synchronous memory model, the harness needs an extra wait state.
