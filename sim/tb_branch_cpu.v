`timescale 1ns / 1ps

module tb_branch_cpu;
    localparam [31:0] RESET_PC = 32'hbfc00000;
    reg clk;
    reg resetn;
    wire        inst_sram_en;
    wire [3:0]  inst_sram_wen;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    reg  [31:0] inst_sram_rdata;
    wire        data_sram_en;
    wire [3:0]  data_sram_wen;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire [31:0] data_sram_rdata;
    wire [31:0] debug_wb_pc;
    wire [3:0]  debug_wb_rf_wen;
    wire [4:0]  debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;

    pipeline_cpu dut (
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
            RESET_PC + 32'd4:  inst_sram_rdata = 32'h11080002; // beq t0, t0, target
            RESET_PC + 32'd8:  inst_sram_rdata = 32'h24090063; // skipped: t1 = 99
            RESET_PC + 32'd12: inst_sram_rdata = 32'h240a004d; // skipped: t2 = 77
            RESET_PC + 32'd16: inst_sram_rdata = 32'h240b002a; // target: t3 = 42
            RESET_PC + 32'd20: inst_sram_rdata = 32'h08000005; // loop at target
            RESET_PC + 32'd24: inst_sram_rdata = 32'h00000000;
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
        #300;
        $display("branch test: t0=%0d t1=%0d t2=%0d t3=%0d",
                 dut.u_regfile.rf[8], dut.u_regfile.rf[9],
                 dut.u_regfile.rf[10], dut.u_regfile.rf[11]);
        $display("performance: cycles=%0d retired=%0d load_use_stalls=%0d taken_branches=%0d",
                 dut.cycle_count, dut.retired_count,
                 dut.load_use_stall_count, dut.taken_branch_count);
        if (dut.u_regfile.rf[8] !== 32'd1 ||
            dut.u_regfile.rf[9] !== 32'd0 ||
            dut.u_regfile.rf[10] !== 32'd0 ||
            dut.u_regfile.rf[11] !== 32'd42) begin
            $display("FAIL: branch flush/target test");
        end
        else begin
            $display("PASS: branch flush/target test");
        end
        $finish;
    end
endmodule
