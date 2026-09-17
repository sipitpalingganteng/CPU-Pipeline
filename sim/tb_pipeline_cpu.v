`timescale 1ns / 1ps

module tb_pipeline_cpu;
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
    reg [31:0] data_mem [0:255];
    integer i;

    mips_pipeline dut (
        .clk(clk),
        .resetn(resetn),
        .inst_sram_en(inst_sram_en),
        .inst_sram_wen(inst_sram_wen),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .data_sram_en(data_sram_en),
        .data_sram_wen(data_sram_wen),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    // Hierarchical probes: XSim only shows the testbench's own nets and the
    // DUT ports, so these references force the pipeline internals into the
    // wave window (add the w_* signals in simulation).
    wire [31:0] w_fs_pc      = dut.fs_pc;
    wire        w_fs_valid   = dut.fs_valid;
    wire [31:0] w_ds_inst    = dut.ds_inst;
    wire        w_ds_valid   = dut.ds_valid;
    wire        w_es_valid   = dut.es_valid;
    wire        w_ms_valid   = dut.ms_valid;
    wire        w_ws_valid   = dut.ws_valid;
    wire        w_stall_if   = dut.stall_if;
    wire        w_stall_id   = dut.stall_id;
    wire        w_br_taken   = dut.br_taken;
    wire [31:0] w_br_target  = dut.br_target;
    wire [31:0] w_nextpc     = dut.nextpc;
    wire        w_es_rmem    = dut.es_res_from_mem;
    wire [ 4:0] w_es_dest    = dut.es_dest;
    wire        w_fwd_rs_mem = dut.forward_rs_from_mem;
    wire        w_fwd_rt_mem = dut.forward_rt_from_mem;
    wire [31:0] w_ms_mem_res = dut.ms_mem_result;

    always @(*) begin
        case (inst_sram_addr)
            RESET_PC + 32'd0:  inst_sram_rdata = 32'h24080005; // addiu t0, zero, 5
            RESET_PC + 32'd4:  inst_sram_rdata = 32'h24090007; // addiu t1, zero, 7
            RESET_PC + 32'd8:  inst_sram_rdata = 32'h01095021; // addu  t2, t0, t1
            RESET_PC + 32'd12: inst_sram_rdata = 32'hac0a0000; // sw    t2, 0(zero)
            RESET_PC + 32'd16: inst_sram_rdata = 32'h8c0b0000; // lw    t3, 0(zero)
            RESET_PC + 32'd20: inst_sram_rdata = 32'h256c0001; // addiu t4, t3, 1
            RESET_PC + 32'd24: inst_sram_rdata = 32'h01886823; // subu  t5, t4, t0
            RESET_PC + 32'd28: inst_sram_rdata = 32'h01aa7024; // and   t6, t5, t2
            RESET_PC + 32'd32: inst_sram_rdata = 32'h01cc7825; // or    t7, t6, t4
            RESET_PC + 32'd36: inst_sram_rdata = 32'h01ed8026; // xor   s0, t7, t5
            default:           inst_sram_rdata = 32'h00000000;
        endcase
    end

    assign data_sram_rdata = data_mem[data_sram_addr[9:2]];

    always @(posedge clk) begin
        if (data_sram_wen != 4'b0000) begin
            data_mem[data_sram_addr[9:2]] <= data_sram_wdata;
        end
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        for (i = 0; i < 256; i = i + 1) begin
            data_mem[i] = 32'b0;
        end
        #40;
        resetn = 1'b1;
        #500;
        $display("t0=%0d t1=%0d t2=%0d t3=%0d t4=%0d t5=%0d t6=%0d t7=%0d s0=%0d",
                 dut.u_regfile.rf[8], dut.u_regfile.rf[9],
                 dut.u_regfile.rf[10], dut.u_regfile.rf[11],
                 dut.u_regfile.rf[12], dut.u_regfile.rf[13],
                 dut.u_regfile.rf[14], dut.u_regfile.rf[15],
                 dut.u_regfile.rf[16]);
        $display("performance: cycles=%0d retired=%0d load_use_stalls=%0d taken_branches=%0d",
                 dut.cycle_count, dut.retired_count,
                 dut.load_use_stall_count, dut.taken_branch_count);
        if (dut.u_regfile.rf[10] !== 32'd12 ||
            dut.u_regfile.rf[11] !== 32'd12 ||
            dut.u_regfile.rf[12] !== 32'd13 ||
            dut.u_regfile.rf[13] !== 32'd8 ||
            dut.u_regfile.rf[16] !== 32'd5) begin
            $display("FAIL: hazard/forwarding test did not produce expected values");
        end
        else begin
            $display("PASS: hazard/forwarding test");
        end
        $finish;
    end
endmodule
