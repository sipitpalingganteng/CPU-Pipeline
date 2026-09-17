// control.v - main control unit (ID stage)
//
// Decodes the instruction into the datapath control bundle. ALU operation
// selection is delegated to alu_control.v, mirroring the single-cycle design.
module control (
    input  wire [31:0] inst,
    output reg  [ 4:0] dest,
    output reg         src1_is_sa,
    output reg         src1_is_pc,
    output reg         src2_is_imm,
    output reg         src2_is_uimm,
    output reg         src2_is_4,
    output reg         res_from_mem,
    output reg         gr_we,
    output reg         mem_we,
    output reg         use_rs,
    output reg         use_rt,
    output reg         is_beq,
    output reg         is_bne,
    output reg         is_blez,
    output reg         is_bgez,
    output reg         is_jal,
    output reg         is_j,
    output reg         is_jr
);
    wire [5:0] op   = inst[31:26];
    wire [4:0] rs   = inst[25:21];
    wire [4:0] rt   = inst[20:16];
    wire [4:0] rd   = inst[15:11];
    wire [5:0] func = inst[ 5: 0];

    always @(*) begin
        dest         = rd;
        src1_is_sa   = 1'b0;
        src1_is_pc   = 1'b0;
        src2_is_imm  = 1'b0;
        src2_is_uimm = 1'b0;
        src2_is_4    = 1'b0;
        res_from_mem = 1'b0;
        gr_we        = 1'b0;
        mem_we       = 1'b0;
        use_rs       = 1'b0;
        use_rt       = 1'b0;
        is_beq       = 1'b0;
        is_bne       = 1'b0;
        is_blez      = 1'b0;
        is_bgez      = 1'b0;
        is_jal       = 1'b0;
        is_j         = 1'b0;
        is_jr        = 1'b0;

        case (op)
            6'h00: begin // R-type
                dest  = rd;
                gr_we = 1'b1;
                case (func)
                    6'h00, 6'h02, 6'h03: begin // sll / srl / sra
                        src1_is_sa = 1'b1;
                        use_rt     = 1'b1;
                    end
                    6'h08: begin // jr
                        is_jr  = 1'b1;
                        gr_we  = 1'b0;
                        use_rs = 1'b1;
                    end
                    default: begin // addu/subu/slt/sltu/and/or/xor/nor
                        use_rs = 1'b1;
                        use_rt = 1'b1;
                    end
                endcase
            end
            6'h09: begin // addiu
                dest = rt; src2_is_imm = 1'b1; gr_we = 1'b1; use_rs = 1'b1;
            end
            6'h0a: begin // slti
                dest = rt; src2_is_imm = 1'b1; gr_we = 1'b1; use_rs = 1'b1;
            end
            6'h0c: begin // andi
                dest = rt; src2_is_uimm = 1'b1; gr_we = 1'b1; use_rs = 1'b1;
            end
            6'h0d: begin // ori
                dest = rt; src2_is_uimm = 1'b1; gr_we = 1'b1; use_rs = 1'b1;
            end
            6'h0f: begin // lui
                dest = rt; src2_is_imm = 1'b1; gr_we = 1'b1;
            end
            6'h23: begin // lw
                dest = rt; src2_is_imm = 1'b1; res_from_mem = 1'b1;
                gr_we = 1'b1; use_rs = 1'b1;
            end
            6'h2b: begin // sw
                src2_is_imm = 1'b1; mem_we = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
            end
            6'h04: begin // beq
                is_beq = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
            end
            6'h05: begin // bne
                is_bne = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
            end
            6'h06: begin // blez
                if (rt == 5'b0) is_blez = 1'b1;
                use_rs = 1'b1;
            end
            6'h01: begin // bgez
                if (rt == 5'h01) is_bgez = 1'b1;
                use_rs = 1'b1;
            end
            6'h02: begin // j
                is_j = 1'b1;
            end
            6'h03: begin // jal
                is_jal     = 1'b1;
                dest       = 5'd31;
                src1_is_pc = 1'b1;
                src2_is_4  = 1'b1;
                gr_we      = 1'b1;
            end
            default: ;
        endcase
    end
endmodule
