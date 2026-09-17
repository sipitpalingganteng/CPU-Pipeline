// alu_control.v - translates a decoded instruction into the 12-bit ALU op
//
// The ALU op is one-hot; bit meanings match the case labels in alu.v:
//   0 add, 1 sub, 2 slt, 3 sltu, 4 and, 5 nor, 6 or, 7 xor,
//   8 sll, 9 srl, 10 sra, 11 lui
module alu_control (
    input  wire [31:0] inst,
    output reg  [11:0] alu_op
);
    wire [5:0] op   = inst[31:26];
    wire [5:0] func = inst[ 5: 0];

    always @(*) begin
        alu_op = 12'b0;
        if (op == 6'h00) begin
            // R-type: the operation lives in the funct field
            case (func)
                6'h21: alu_op[ 0] = 1'b1; // addu
                6'h23: alu_op[ 1] = 1'b1; // subu
                6'h2a: alu_op[ 2] = 1'b1; // slt
                6'h2b: alu_op[ 3] = 1'b1; // sltu
                6'h24: alu_op[ 4] = 1'b1; // and
                6'h27: alu_op[ 5] = 1'b1; // nor
                6'h25: alu_op[ 6] = 1'b1; // or
                6'h26: alu_op[ 7] = 1'b1; // xor
                6'h00: alu_op[ 8] = 1'b1; // sll
                6'h02: alu_op[ 9] = 1'b1; // srl
                6'h03: alu_op[10] = 1'b1; // sra
                default: ;
            endcase
        end
        else begin
            // I-type / J-type: the operation is fixed by the opcode
            case (op)
                6'h09: alu_op[ 0] = 1'b1; // addiu
                6'h0a: alu_op[ 2] = 1'b1; // slti
                6'h0c: alu_op[ 4] = 1'b1; // andi
                6'h0d: alu_op[ 6] = 1'b1; // ori
                6'h0f: alu_op[11] = 1'b1; // lui
                6'h23: alu_op[ 0] = 1'b1; // lw
                6'h2b: alu_op[ 0] = 1'b1; // sw
                6'h03: alu_op[ 0] = 1'b1; // jal
                default: ;
            endcase
        end
    end
endmodule
