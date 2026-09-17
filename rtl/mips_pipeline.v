// mips_pipeline.v - five-stage MIPS pipeline
//
// Continuation of the single-cycle mips_single design: the same building
// blocks (pc, control, alu_control, regfile, sign_extend, shift_left2, alu)
// are split across IF / ID / EX / MEM / WB with pipeline registers between
// them, forwarding, load-use stalls and branch resolution in ID.
module mips_pipeline(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_en,
    output [ 3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire to_fs_valid;
wire [31:0] seq_pc;
wire [31:0] nextpc;
// fs_ -- IF  stage
wire        fs_allowin;
wire        fs_ready_go;
wire        fs_to_ds_valid;
reg         fs_valid;
wire [31:0] fs_pc;
wire [31:0] inst;
// ds_ -- ID  stage
wire        ds_allowin;
wire        ds_ready_go;
wire        ds_to_es_valid;
reg         ds_valid;
reg  [31:0] ds_pc;
reg  [31:0] ds_inst;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [15:0] imm;
wire [25:0] jidx;
wire [ 4:0] dest;
wire [11:0] alu_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_uimm;
wire        src2_is_4;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire        use_rs;
wire        use_rt;
wire        is_beq;
wire        is_bne;
wire        is_blez;
wire        is_bgez;
wire        is_jal;
wire        is_j;
wire        is_jr;
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire        rs_eq_rt;
wire        rs_le_zero;
wire        rs_ge_zero;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] imm_sext;
wire [31:0] branch_offset;
wire        stall_if;
wire        stall_id;
wire        forward_rs_from_ex;
wire        forward_rs_from_mem;
wire        forward_rt_from_ex;
wire        forward_rt_from_mem;
// es_ -- EXE stage
wire        es_allowin;
wire        es_ready_go;
wire        es_to_ms_valid;
reg         es_valid;
reg  [31:0] es_pc;
reg  [31:0] es_rs_value;
reg  [31:0] es_rt_value;
reg  [15:0] es_imm;
reg  [11:0] es_alu_op;
reg         es_src1_is_sa;
reg         es_src1_is_pc;
reg         es_src2_is_imm;
reg         es_src2_is_uimm;
reg         es_src2_is_4;
reg         es_res_from_mem;
reg         es_gr_we;
reg         es_mem_we;
reg  [ 4:0] es_dest;
wire [31:0] es_imm_sext;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [31:0] alu_result;
// ms_ -- MEM stage
wire        ms_allowin;
wire        ms_ready_go;
wire        ms_to_ws_valid;
reg         ms_valid;
reg  [31:0] ms_pc;
reg  [ 4:0] ms_dest;
reg         ms_res_from_mem;
reg         ms_gr_we;
reg  [31:0] ms_alu_result;
// The data bus is combinational, so the read data is captured at the
// EX/MEM boundary. Without this a load whose result is not consumed by the
// immediately following instruction (no load-use stall) would sample the
// next instruction's address instead of its own.
reg  [31:0] ms_mem_result;
wire [31:0] mem_result;
wire [31:0] final_result;
// ws_ -- WB  stage
wire        ws_allowin;
wire        ws_ready_go;
reg         ws_valid;
reg  [31:0] ws_pc;
reg         ws_gr_we;
reg  [ 4:0] ws_dest;
reg  [31:0] ws_final_result;
wire        rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

// Simulation-visible performance counters. They do not affect the CPU interface.
reg [31:0] cycle_count;
reg [31:0] retired_count;
reg [31:0] load_use_stall_count;
reg [31:0] taken_branch_count;

always @(posedge clk) begin
    if (reset) begin
        cycle_count          <= 32'b0;
        retired_count        <= 32'b0;
        load_use_stall_count <= 32'b0;
        taken_branch_count   <= 32'b0;
    end
    else begin
        cycle_count <= cycle_count + 32'd1;
        if (ws_valid)
            retired_count <= retired_count + 32'd1;
        if (stall_if)
            load_use_stall_count <= load_use_stall_count + 32'd1;
        if (br_taken)
            taken_branch_count <= taken_branch_count + 32'd1;
    end
end


// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc = fs_pc + 3'h4;
assign nextpc = br_taken ? br_target : seq_pc;

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin && !stall_if;
assign fs_to_ds_valid = fs_valid && fs_ready_go;
pc #(.RESET_VALUE(32'hbfbffffc)) u_pc(
    .clk    (clk   ),
    .reset  (reset ),
    .pc_en  (to_fs_valid && fs_allowin),
    .next_pc(nextpc),
    .pc     (fs_pc )
);
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
// The test memory is combinational; address the instruction held by IF.
// Using nextpc here advances the visible memory word before IF/ID captures it.
assign inst_sram_addr  = fs_pc;
assign inst_sram_wdata = 32'b0;

assign inst            = inst_sram_rdata;

// ID stage
assign ds_ready_go    = 1'b1;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin && !stall_id;
assign ds_to_es_valid = ds_valid && ds_ready_go && !stall_id;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid && !br_taken;
    end

    if (fs_to_ds_valid && ds_allowin && !br_taken) begin
        ds_pc   <= fs_pc;
        ds_inst <= inst;
    end
end

assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

control u_control(
    .inst        (ds_inst     ),
    .dest        (dest        ),
    .src1_is_sa  (src1_is_sa  ),
    .src1_is_pc  (src1_is_pc  ),
    .src2_is_imm (src2_is_imm ),
    .src2_is_uimm(src2_is_uimm),
    .src2_is_4   (src2_is_4   ),
    .res_from_mem(res_from_mem),
    .gr_we       (gr_we       ),
    .mem_we      (mem_we      ),
    .use_rs      (use_rs      ),
    .use_rt      (use_rt      ),
    .is_beq      (is_beq      ),
    .is_bne      (is_bne      ),
    .is_blez     (is_blez     ),
    .is_bgez     (is_bgez     ),
    .is_jal      (is_jal      ),
    .is_j        (is_j        ),
    .is_jr       (is_jr       )
);
alu_control u_alu_control(
    .inst  (ds_inst),
    .alu_op(alu_op )
);

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );
hazard u_hazard(
    .id_rs_valid    (use_rs),
    .id_rt_valid    (use_rt),
    .id_rs          (rs    ),
    .id_rt          (rt    ),
    .ex_dest        (es_dest),
    .ex_gr_we       (es_gr_we && es_valid),
    .ex_res_from_mem(es_res_from_mem),
    .stall_if       (stall_if),
    .stall_id       (stall_id)
);
forward u_forward(
    .id_rs_valid         (use_rs),
    .id_rt_valid         (use_rt),
    .id_rs               (rs    ),
    .id_rt               (rt    ),
    .ex_dest             (es_dest),
    .ex_gr_we            (es_gr_we && es_valid),
    .ex_res_from_mem     (es_res_from_mem),
    .mem_dest            (ms_dest),
    .mem_gr_we           (ms_gr_we && ms_valid),
    .forward_rs_from_ex  (forward_rs_from_ex ),
    .forward_rs_from_mem (forward_rs_from_mem),
    .forward_rt_from_ex  (forward_rt_from_ex ),
    .forward_rt_from_mem (forward_rt_from_mem)
);

assign rs_value = forward_rs_from_ex  ? alu_result :
                  forward_rs_from_mem ? final_result :
                  (rf_we && (rf_waddr != 5'b0) && (rf_waddr == rs)) ? rf_wdata :
                  rf_rdata1;
assign rt_value = forward_rt_from_ex  ? alu_result :
                  forward_rt_from_mem ? final_result :
                  (rf_we && (rf_waddr != 5'b0) && (rf_waddr == rt)) ? rf_wdata :
                  rf_rdata2;

assign rs_eq_rt   = (rs_value == rt_value);
assign rs_le_zero = ($signed(rs_value) <= 0);
assign rs_ge_zero = ($signed(rs_value) >= 0);
assign br_taken = (   is_beq  &&  rs_eq_rt
                   || is_bne  && !rs_eq_rt
                   || is_blez &&  rs_le_zero
                   || is_bgez &&  rs_ge_zero
                   || is_jal
                   || is_j
                   || is_jr
                  ) && ds_valid;

sign_extend u_sext_branch(
    .imm16(imm          ),
    .imm32(imm_sext     )
);
shift_left2 u_sl2_branch(
    .in (imm_sext     ),
    .out(branch_offset)
);
assign br_target = (is_beq || is_bne || is_blez || is_bgez)
                                          ? (ds_pc + 32'd4 + branch_offset) :
                   (is_jr)                ? rs_value :
                   /*is_jal || is_j*/       {ds_pc[31:28], jidx[25:0], 2'b0};

// EXE stage
assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid = es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        es_pc           <= ds_pc;
        es_rs_value     <= rs_value;
        es_rt_value     <= rt_value;
        es_imm          <= imm;
        es_alu_op       <= alu_op;
        es_src1_is_sa   <= src1_is_sa;
        es_src1_is_pc   <= src1_is_pc;
        es_src2_is_imm  <= src2_is_imm;
        es_src2_is_uimm <= src2_is_uimm;
        es_src2_is_4    <= src2_is_4;
        es_res_from_mem <= res_from_mem;
        es_gr_we        <= gr_we;
        es_mem_we       <= mem_we;
        es_dest         <= dest;
    end
end

sign_extend u_sext_alu(
    .imm16(es_imm     ),
    .imm32(es_imm_sext)
);
assign alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                  es_src1_is_pc  ? es_pc[31:0] :
                                   es_rs_value;
assign alu_src2 = es_src2_is_imm  ? es_imm_sext :
                  es_src2_is_uimm ? {16'b0, es_imm[15:0]} :
                  es_src2_is_4    ? 32'd4 :
                                    es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we&&es_valid ? 4'hf : 4'h0;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = es_rt_value;

// MEM stage
assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        ms_pc           <= es_pc;
        ms_dest         <= es_dest;
        ms_res_from_mem <= es_res_from_mem;
        ms_gr_we        <= es_gr_we;
        ms_alu_result   <= alu_result;
        ms_mem_result   <= data_sram_rdata;
    end
end

assign mem_result = ms_mem_result;

assign final_result = ms_res_from_mem ? mem_result : ms_alu_result;

// WB stage
assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ws_pc           <= ms_pc;
        ws_gr_we        <= ms_gr_we;
        ws_dest         <= ms_dest;
        ws_final_result <= final_result;
    end
end

assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
