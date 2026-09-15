module alu (
    input  [11:0] alu_op,
    input  [31:0] alu_src1,
    input  [31:0] alu_src2,
    output reg [31:0] alu_result
);
    always @(*) begin
        case (1'b1)
            alu_op[0]:  alu_result = alu_src1 + alu_src2;
            alu_op[1]:  alu_result = alu_src1 - alu_src2;
            alu_op[2]:  alu_result = ($signed(alu_src1) < $signed(alu_src2)) ? 32'd1 : 32'd0;
            alu_op[3]:  alu_result = (alu_src1 < alu_src2) ? 32'd1 : 32'd0;
            alu_op[4]:  alu_result = alu_src1 & alu_src2;
            alu_op[5]:  alu_result = ~(alu_src1 | alu_src2);
            alu_op[6]:  alu_result = alu_src1 | alu_src2;
            alu_op[7]:  alu_result = alu_src1 ^ alu_src2;
            alu_op[8]:  alu_result = alu_src2 << alu_src1[4:0];
            alu_op[9]:  alu_result = alu_src2 >> alu_src1[4:0];
            alu_op[10]: alu_result = $signed(alu_src2) >>> alu_src1[4:0];
            alu_op[11]: alu_result = {alu_src2[15:0], 16'b0};
            default:    alu_result = 32'b0;
        endcase
    end
endmodule
