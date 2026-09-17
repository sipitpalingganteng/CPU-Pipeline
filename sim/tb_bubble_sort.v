`timescale 1ns / 1ps

// Bubble sort: the CPU sorts an 8-word array in data memory in place.
// The testbench preloads {5,3,9,1,7,2,8,4}; the program must leave it sorted
// ascending and then write a completion flag to word 0x100.
//
// Source: programs/bubble_sort.s (assembled with the LLVM MIPS backend).
module tb_bubble_sort;
    localparam [31:0] RESET_PC  = 32'hbfc00000;
    localparam integer N        = 8;
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
            RESET_PC + 32'd0:   inst_sram_rdata = 32'h24080000; // addiu t0, zero, 0   (base)
            RESET_PC + 32'd4:   inst_sram_rdata = 32'h24090008; // addiu t1, zero, 8   (n)
            RESET_PC + 32'd8:   inst_sram_rdata = 32'h24190000; // addiu t9, zero, 0   (pass)
            RESET_PC + 32'd12:  inst_sram_rdata = 32'h0329602a; // slt   t4, t9, t1
            RESET_PC + 32'd16:  inst_sram_rdata = 32'h11800016; // beq   t4, zero, done
            RESET_PC + 32'd20:  inst_sram_rdata = 32'h00000000; // nop
            RESET_PC + 32'd24:  inst_sram_rdata = 32'h240a0000; // addiu t2, zero, 0   (i)
            RESET_PC + 32'd28:  inst_sram_rdata = 32'h252bffff; // addiu t3, t1, -1
            RESET_PC + 32'd32:  inst_sram_rdata = 32'h01795823; // subu  t3, t3, t9    (n-1-pass)
            RESET_PC + 32'd36:  inst_sram_rdata = 32'h014b602a; // slt   t4, t2, t3
            RESET_PC + 32'd40:  inst_sram_rdata = 32'h1180000d; // beq   t4, zero, next_pass
            RESET_PC + 32'd44:  inst_sram_rdata = 32'h00000000; // nop
            RESET_PC + 32'd48:  inst_sram_rdata = 32'h000a6880; // sll   t5, t2, 2
            RESET_PC + 32'd52:  inst_sram_rdata = 32'h01a86821; // addu  t5, t5, t0
            RESET_PC + 32'd56:  inst_sram_rdata = 32'h8dae0000; // lw    t6, 0(t5)
            RESET_PC + 32'd60:  inst_sram_rdata = 32'h8daf0004; // lw    t7, 4(t5)
            RESET_PC + 32'd64:  inst_sram_rdata = 32'h01eec02a; // slt   t8, t7, t6
            RESET_PC + 32'd68:  inst_sram_rdata = 32'h13000003; // beq   t8, zero, no_swap
            RESET_PC + 32'd72:  inst_sram_rdata = 32'h00000000; // nop
            RESET_PC + 32'd76:  inst_sram_rdata = 32'hadaf0000; // sw    t7, 0(t5)
            RESET_PC + 32'd80:  inst_sram_rdata = 32'hadae0004; // sw    t6, 4(t5)
            RESET_PC + 32'd84:  inst_sram_rdata = 32'h254a0001; // addiu t2, t2, 1
            RESET_PC + 32'd88:  inst_sram_rdata = 32'h0bf00009; // j     outer_cond
            RESET_PC + 32'd92:  inst_sram_rdata = 32'h00000000; // nop
            RESET_PC + 32'd96:  inst_sram_rdata = 32'h27390001; // addiu t9, t9, 1
            RESET_PC + 32'd100: inst_sram_rdata = 32'h0bf00003; // j     outer
            RESET_PC + 32'd104: inst_sram_rdata = 32'h00000000; // nop
            RESET_PC + 32'd108: inst_sram_rdata = 32'h24080001; // done: addiu t0, zero, 1
            RESET_PC + 32'd112: inst_sram_rdata = 32'h240d0100; // addiu t5, zero, 0x100
            RESET_PC + 32'd116: inst_sram_rdata = 32'hada80000; // sw    t0, 0(t5)
            RESET_PC + 32'd120: inst_sram_rdata = 32'h0bf0001e; // halt: j halt
            RESET_PC + 32'd124: inst_sram_rdata = 32'h00000000; // nop
            default:            inst_sram_rdata = 32'h00000000;
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
        data_mem[0] = 32'd5;
        data_mem[1] = 32'd3;
        data_mem[2] = 32'd9;
        data_mem[3] = 32'd1;
        data_mem[4] = 32'd7;
        data_mem[5] = 32'd2;
        data_mem[6] = 32'd8;
        data_mem[7] = 32'd4;
        #40;
        resetn = 1'b1;
        $write("unsorted array:");
          for (i = 0; i < N; i = i + 1)
             $write(" %0d", data_mem[i]);
        $write("\n");

        $display("tb_bubble_sort: running (waiting for completion flag)...");
        for (i = 0; i < 200000 && data_mem[FLAG_WORD] !== 32'd1; i = i + 1)
            @(posedge clk);

        if (data_mem[FLAG_WORD] !== 32'd1) begin
            $display("FAIL: bubble sort did not finish (timeout)");
        end
        else begin
            $write("sorted array:");
            for (i = 0; i < N; i = i + 1)
                $write(" %0d", data_mem[i]);
            $write("\n");
            if (data_mem[0] !== 32'd1 || data_mem[1] !== 32'd2 ||
                data_mem[2] !== 32'd3 || data_mem[3] !== 32'd4 ||
                data_mem[4] !== 32'd5 || data_mem[5] !== 32'd7 ||
                data_mem[6] !== 32'd8 || data_mem[7] !== 32'd9)
                $display("FAIL: array not sorted");
            else
                $display("PASS: bubble sort");
        end
        $display("performance: cycles=%0d retired=%0d load_use_stalls=%0d taken_branches=%0d",
                 dut.cycle_count, dut.retired_count,
                 dut.load_use_stall_count, dut.taken_branch_count);
        $finish;
    end
endmodule
