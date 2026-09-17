// shift_left2.v - shift left by 2 bits (branch/jump target calculation)
module shift_left2 (
    input  wire [31:0] in,
    output wire [31:0] out
);
    assign out = {in[29:0], 2'b00};
endmodule
