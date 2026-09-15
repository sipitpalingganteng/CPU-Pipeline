module decoder_6_64(
    input  [5:0] in,
    output [63:0] out
);
    reg [63:0] o;
    integer i;
    always @(*) begin
        o = 64'b0;
        for (i = 0; i < 64; i = i + 1) begin
            if (i == in) o[i] = 1'b1;
        end
    end
    assign out = o;
endmodule
