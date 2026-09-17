`timescale 1ns / 1ps

// Regression test for the instructions added to run compiled C:
// slti, andi, ori, j, blez, bgez, plus the EX/MEM load-data capture that
// makes a load work even when its result is not used by the very next
// instruction (i.e. without a load-use stall).
module tb_isa_ext;
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
    reg  [31:0] data_mem [0:15];

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

    assign data_sram_rdata = data_mem[data_sram_addr[5:2]];

    always @(posedge clk) begin
        if (data_sram_wen != 4'b0000)
            data_mem[data_sram_addr[5:2]] <= data_sram_wdata;
    end

    always @(*) begin
        case (inst_sram_addr)
            RESET_PC + 32'd0:  inst_sram_rdata = 32'h24080005; // addiu t0, zero, 5
            RESET_PC + 32'd4:  inst_sram_rdata = 32'h290a000a; // slti  t2, t0, 10
            RESET_PC + 32'd8:  inst_sram_rdata = 32'h290b0003; // slti  t3, t0, 3
            RESET_PC + 32'd12: inst_sram_rdata = 32'h240c00ff; // addiu t4, zero, 0xff
            RESET_PC + 32'd16: inst_sram_rdata = 32'h318c000f; // andi  t4, t4, 0x0f
            RESET_PC + 32'd20: inst_sram_rdata = 32'h358d0010; // ori   t5, t4, 0x10
            RESET_PC + 32'd24: inst_sram_rdata = 32'h240e002a; // addiu t6, zero, 42
            RESET_PC + 32'd28: inst_sram_rdata = 32'hac0e0000; // sw    t6, 0(zero)
            RESET_PC + 32'd32: inst_sram_rdata = 32'h8c0f0000; // lw    t7, 0(zero)
            RESET_PC + 32'd36: inst_sram_rdata = 32'h24100007; // addiu s0, zero, 7
            RESET_PC + 32'd40: inst_sram_rdata = 32'h020f8021; // addu  s0, s0, t7
            RESET_PC + 32'd44: inst_sram_rdata = 32'h24110000; // addiu s1, zero, 0
            RESET_PC + 32'd48: inst_sram_rdata = 32'h04010001; // bgez  zero, ge
            RESET_PC + 32'd52: inst_sram_rdata = 32'h24110001; //   skipped: s1 = 1
            RESET_PC + 32'd56: inst_sram_rdata = 32'h2412ffff; // ge: addiu s2, zero, -1
            RESET_PC + 32'd60: inst_sram_rdata = 32'h1a400001; // blez  s2, le
            RESET_PC + 32'd64: inst_sram_rdata = 32'h24120002; //   skipped: s2 = 2
            RESET_PC + 32'd68: inst_sram_rdata = 32'h0bf00014; // j     done (0x50)
            RESET_PC + 32'd72: inst_sram_rdata = 32'h24130009; //   skipped: s3 = 9
            RESET_PC + 32'd76: inst_sram_rdata = 32'h00000000; //   delay slot nop
            RESET_PC + 32'd80: inst_sram_rdata = 32'h24130005; // done: addiu s3, zero, 5
            RESET_PC + 32'd84: inst_sram_rdata = 32'h0bf00015; // loop: j loop
            RESET_PC + 32'd88: inst_sram_rdata = 32'h00000000; //   delay slot nop
            default:           inst_sram_rdata = 32'h00000000;
        endcase
    end

    integer i;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        for (i = 0; i < 16; i = i + 1)
            data_mem[i] = 32'b0;
        #40;
        resetn = 1'b1;
        #400;
        $display("isa ext: t2=%0d t3=%0d t4=%0d t5=%0d t7=%0d s0=%0d s1=%0d s2=%0d s3=%0d",
                 dut.u_regfile.rf[10], dut.u_regfile.rf[11],
                 dut.u_regfile.rf[12], dut.u_regfile.rf[13],
                 dut.u_regfile.rf[15], dut.u_regfile.rf[16],
                 dut.u_regfile.rf[17], dut.u_regfile.rf[18],
                 dut.u_regfile.rf[19]);
        $display("performance: cycles=%0d retired=%0d load_use_stalls=%0d taken_branches=%0d",
                 dut.cycle_count, dut.retired_count,
                 dut.load_use_stall_count, dut.taken_branch_count);
        if (dut.u_regfile.rf[10] !== 32'd1 ||
            dut.u_regfile.rf[11] !== 32'd0 ||
            dut.u_regfile.rf[12] !== 32'd15 ||
            dut.u_regfile.rf[13] !== 32'd31 ||
            dut.u_regfile.rf[15] !== 32'd42 ||
            dut.u_regfile.rf[16] !== 32'd49 ||
            dut.u_regfile.rf[17] !== 32'd0 ||
            dut.u_regfile.rf[18] !== 32'hffffffff ||
            dut.u_regfile.rf[19] !== 32'd5) begin
            $display("FAIL: ISA extension / load capture test");
        end
        else begin
            $display("PASS: ISA extension / load capture test");
        end
        $finish;
    end
endmodule
