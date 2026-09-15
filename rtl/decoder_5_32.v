module decoder_5_32(
    input  [4:0] in,
    output [31:0] out
);
    reg [31:0] o;
    integer i;
    always @(*) begin
        o = 32'b0;
        for (i = 0; i < 32; i = i + 1) begin
            if (i == in) o[i] = 1'b1;
        end
    end
    assign out = o;
endmodule
