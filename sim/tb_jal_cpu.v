`timescale 1ns / 1ps

// Regression test for jal: branches are resolved in ID with no delay slot,
// so jal must link PC + 4. The instruction after the call must execute when
// the subroutine returns.
module tb_jal_cpu;
    localparam [31:0] RESET_PC = 32'hbfc00000;
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

    assign data_sram_rdata = 32'b0;

    always @(*) begin
        case (inst_sram_addr)
            RESET_PC + 32'd0:  inst_sram_rdata = 32'h24080001; // addiu t0, zero, 1
            RESET_PC + 32'd4:  inst_sram_rdata = 32'h0ff00004; // jal sub (0x10)
            RESET_PC + 32'd8:  inst_sram_rdata = 32'h24090002; // addiu t1, zero, 2
            RESET_PC + 32'd12: inst_sram_rdata = 32'h1000ffff; // done: beq zero, zero, done
            RESET_PC + 32'd16: inst_sram_rdata = 32'h240a0003; // sub: addiu t2, zero, 3
            RESET_PC + 32'd20: inst_sram_rdata = 32'h03e00008; // jr ra
            default:           inst_sram_rdata = 32'h00000000;
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        #40;
        resetn = 1'b1;
        #400;
        $display("jal test: t0=%0d t1=%0d t2=%0d",
                 dut.u_regfile.rf[8], dut.u_regfile.rf[9],
                 dut.u_regfile.rf[10]);
        $display("performance: cycles=%0d retired=%0d load_use_stalls=%0d taken_branches=%0d",
                 dut.cycle_count, dut.retired_count,
                 dut.load_use_stall_count, dut.taken_branch_count);
        if (dut.u_regfile.rf[8] !== 32'd1 ||
            dut.u_regfile.rf[9] !== 32'd2 ||
            dut.u_regfile.rf[10] !== 32'd3) begin
            $display("FAIL: jal link/return test");
        end
        else begin
            $display("PASS: jal link/return test");
        end
        $finish;
    end
endmodule
