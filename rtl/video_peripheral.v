module video_peripheral #(
    parameter integer WIDTH  = 32,
    parameter integer HEIGHT = 16
) (
    input         clk,
    input         resetn,
    input         write_en,
    input  [31:0] write_addr,
    input  [31:0] write_data,
    input  [5:0]  pixel_x,
    input  [4:0]  pixel_y,
    output        pixel_on,
    output [1:0]  frame_index
);
    localparam [31:0] FRAME_INDEX_ADDR = 32'h00001000;
    reg [1:0] frame_index_reg;

    always @(posedge clk) begin
        if (!resetn)
            frame_index_reg <= 2'b0;
        else if (write_en && (write_addr == FRAME_INDEX_ADDR))
            frame_index_reg <= write_data[1:0];
    end

    assign frame_index = frame_index_reg;

    mono_frame_rom #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) u_frame_rom (
        .frame_index(frame_index_reg),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_on(pixel_on)
    );
endmodule
