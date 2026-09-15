module mono_frame_rom #(
    parameter integer WIDTH  = 32,
    parameter integer HEIGHT = 16
) (
    input  [1:0] frame_index,
    input  [5:0] pixel_x,
    input  [4:0] pixel_y,
    output reg   pixel_on
);
    always @(*) begin
        pixel_on = 1'b0;
        if ((pixel_x < WIDTH) && (pixel_y < HEIGHT)) begin
            case (frame_index)
                2'd0: pixel_on = (pixel_x == pixel_y) ||
                                 (pixel_x == (WIDTH - 1 - pixel_y));
                2'd1: pixel_on = (pixel_x > 10) && (pixel_x < 22) &&
                                 (pixel_y > 3) && (pixel_y < 13);
                2'd2: pixel_on = ((pixel_x / 4 + pixel_y / 4) % 2) == 1;
                2'd3: pixel_on = (pixel_x == WIDTH / 2) ||
                                 (pixel_y == HEIGHT / 2);
                default: pixel_on = 1'b0;
            endcase
        end
    end
endmodule
