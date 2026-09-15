module bad_apple_video_peripheral #(
    parameter integer WIDTH  = 64,
    parameter integer HEIGHT = 48
) (
    input         clk,
    input         resetn,
    input         write_en,
    input  [31:0] write_addr,
    input  [31:0] write_data,
    input  [5:0]  pixel_x,
    input  [5:0]  pixel_y,
    output        pixel_on,
    output [4:0]  frame_index
);
    localparam [31:0] FRAME_INDEX_ADDR = 32'h00001000;
    reg [4:0] frame_index_reg;

    always @(posedge clk) begin
        if (!resetn)
            frame_index_reg <= 5'b0;
        else if (write_en && (write_addr == FRAME_INDEX_ADDR))
            frame_index_reg <= write_data[4:0];
    end

    assign frame_index = frame_index_reg;

    bad_apple_frame_rom #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .FRAME_COUNT(20)
    ) u_frame_rom (
        .frame_index(frame_index_reg),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_on(pixel_on)
    );
endmodule
