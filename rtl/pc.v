// pc.v - program counter
//
// Synchronous reset with a loadable reset value. The pipeline pre-loads
// RESET_PC - 4 so that the first enabled update lands exactly on the reset
// vector, matching the valid/allowin fetch scheme in mips_pipeline.
module pc #(
    parameter [31:0] RESET_VALUE = 32'hbfbffffc
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_en,
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (reset)
            pc <= RESET_VALUE;
        else if (pc_en)
            pc <= next_pc;
    end
endmodule
