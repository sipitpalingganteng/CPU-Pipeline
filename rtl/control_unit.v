module control_unit (
    input  [31:0] inst,
    output [11:0] alu_op,
    output        src1_is_sa,
    output        src1_is_pc,
    output        src2_is_imm,
    output        src2_is_8,
    output        res_from_mem,
    output        dst_is_r31,
    output        dst_is_rt,
    output        gr_we,
    output        mem_we,
    output        br_taken
);
    // Control decode will be added in the next milestone.
    assign alu_op      = 12'b0;
    assign src1_is_sa  = 1'b0;
    assign src1_is_pc  = 1'b0;
    assign src2_is_imm = 1'b0;
    assign src2_is_8   = 1'b0;
    assign res_from_mem= 1'b0;
    assign dst_is_r31  = 1'b0;
    assign dst_is_rt   = 1'b0;
    assign gr_we       = 1'b0;
    assign mem_we      = 1'b0;
    assign br_taken    = 1'b0;
endmodule
