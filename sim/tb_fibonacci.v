`timescale 1ns / 1ps

// Fibonacci: the CPU computes fib(0..9) iteratively and stores the results at
// data words 0..9, then writes a completion flag to word 0x100.
//
// Expected: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34
// Source: programs/fibonacci.s (assembled with the LLVM MIPS backend).
module tb_fibonacci;
    localparam [31:0] RESET_PC  = 32'hbfc00000;
    localparam integer N        = 10;
    localparam integer FLAG_WORD = 64;   // 0x100 >> 2

    reg clk;
    reg resetn;
    wire        inst_sram_en;
    wire [ 3:0] inst_sram_wen;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    reg  [31:0] inst_sram_rdata;
    wire        data_sram_en;
    wire [ 3:0] data_sram_wen;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire [31:0] data_sram_rdata;
    wire [31:0] debug_wb_pc;
    wire [ 3:0] debug_wb_rf_wen;
    wire [ 4:0] debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;
    reg  [31:0] data_mem [0:255];
    reg  [31:0] expected [0:9];
    integer i;

    mips_pipeline dut (
        .clk(clk), .resetn(resetn),
        .inst_sram_en(inst_sram_en), .inst_sram_wen(inst_sram_wen),
        .inst_sram_addr(inst_sram_addr), .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .data_sram_en(data_sram_en), .data_sram_wen(data_sram_wen),
        .data_sram_addr(data_sram_addr), .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata),
        .debug_wb_pc(debug_wb_pc), .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    assign data_sram_rdata = data_mem[data_sram_addr[9:2]];

    always @(posedge clk) begin
        if (data_sram_wen != 4'b0000)
            data_mem[data_sram_addr[9:2]] <= data_sram_wdata;
    end

    always @(*) begin
        case (inst_sram_addr)
            RESET_PC + 32'd0:  inst_sram_rdata = 32'h24080000; // addiu t0, zero, 0   (a)
            RESET_PC + 32'd4:  inst_sram_rdata = 32'h24090001; // addiu t1, zero, 1   (b)
            RESET_PC + 32'd8:  inst_sram_rdata = 32'h240a0000; // addiu t2, zero, 0   (i)
            RESET_PC + 32'd12: inst_sram_rdata = 32'h240b000a; // addiu t3, zero, 10  (count)
            RESET_PC + 32'd16: inst_sram_rdata = 32'h240c0000; // addiu t4, zero, 0   (base)
            RESET_PC + 32'd20: inst_sram_rdata = 32'h014b682a; // loop: slt t5, t2, t3
            RESET_PC + 32'd24: inst_sram_rdata = 32'h11a0000a; // beq t5, zero, done
            RESET_PC + 32'd28: inst_sram_rdata = 32'h00000000; // nop
            RESET_PC + 32'd32: inst_sram_rdata = 32'h000a7080; // sll   t6, t2, 2
            RESET_PC + 32'd36: inst_sram_rdata = 32'h01cc7021; // addu  t6, t6, t4
            RESET_PC + 32'd40: inst_sram_rdata = 32'hadc80000; // sw    t0, 0(t6)
            RESET_PC + 32'd44: inst_sram_rdata = 32'h01097821; // addu  t7, t0, t1
            RESET_PC + 32'd48: inst_sram_rdata = 32'h01204021; // addu  t0, t1, zero
            RESET_PC + 32'd52: inst_sram_rdata = 32'h01e04821; // addu  t1, t7, zero
            RESET_PC + 32'd56: inst_sram_rdata = 32'h254a0001; // addiu t2, t2, 1
            RESET_PC + 32'd60: inst_sram_rdata = 32'h0bf00005; // j     loop
            RESET_PC + 32'd64: inst_sram_rdata = 32'h00000000; // nop
            RESET_PC + 32'd68: inst_sram_rdata = 32'h240d0001; // done: addiu t5, zero, 1
            RESET_PC + 32'd72: inst_sram_rdata = 32'h240e0100; // addiu t6, zero, 0x100
            RESET_PC + 32'd76: inst_sram_rdata = 32'hadcd0000; // sw    t5, 0(t6)
            RESET_PC + 32'd80: inst_sram_rdata = 32'h0bf00014; // halt: j halt
            RESET_PC + 32'd84: inst_sram_rdata = 32'h00000000; // nop
            default:           inst_sram_rdata = 32'h00000000;
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        for (i = 0; i < 256; i = i + 1)
            data_mem[i] = 32'b0;
        expected[0] = 32'd0;
        expected[1] = 32'd1;
        expected[2] = 32'd1;
        expected[3] = 32'd2;
        expected[4] = 32'd3;
        expected[5] = 32'd5;
        expected[6] = 32'd8;
        expected[7] = 32'd13;
        expected[8] = 32'd21;
        expected[9] = 32'd34;
        #40;
        resetn = 1'b1;

        $display("tb_fibonacci: running (waiting for completion flag)...");
        for (i = 0; i < 200000 && data_mem[FLAG_WORD] !== 32'd1; i = i + 1)
            @(posedge clk);

        if (data_mem[FLAG_WORD] !== 32'd1) begin
            $display("FAIL: fibonacci did not finish (timeout)");
        end
        else begin
            $write("fib(0..9):");
            for (i = 0; i < N; i = i + 1)
                $write(" %0d", data_mem[i]);
            $write("\n");
            for (i = 0; i < N; i = i + 1) begin
                if (data_mem[i] !== expected[i]) begin
                    $display("FAIL: fib(%0d) = %0d, expected %0d",
                             i, data_mem[i], expected[i]);
                    i = N;
                end
            end
            if (i == N)
                $display("PASS: fibonacci");
        end
        $display("performance: cycles=%0d retired=%0d load_use_stalls=%0d taken_branches=%0d",
                 dut.cycle_count, dut.retired_count,
                 dut.load_use_stall_count, dut.taken_branch_count);
        $finish;
    end
endmodule
