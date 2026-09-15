`timescale 1ns / 1ps

module tb_mono_video;
    localparam integer WIDTH  = 32;
    localparam integer HEIGHT = 16;

    reg         clk;
    reg         resetn;
    reg         write_en;
    reg  [31:0] write_addr;
    reg  [31:0] write_data;
    wire [1:0]  frame_index;
    reg  [5:0] pixel_x;
    reg  [4:0] pixel_y;
    wire       pixel_on;
    integer frame_file;
    integer x;
    integer y;
    integer frame;

    video_peripheral #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .write_en(write_en),
        .write_addr(write_addr),
        .write_data(write_data),
        .frame_index(frame_index),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_on(pixel_on)
    );

    task write_frame;
        input integer frame_number;
        begin
            @(negedge clk);
            write_en = 1'b1;
            write_addr = 32'h00001000;
            write_data = frame_number;
            @(negedge clk);
            write_en = 1'b0;
            case (frame_number)
                0: frame_file = $fopen("frame_0.pgm", "w");
                1: frame_file = $fopen("frame_1.pgm", "w");
                2: frame_file = $fopen("frame_2.pgm", "w");
                3: frame_file = $fopen("frame_3.pgm", "w");
                default: frame_file = 0;
            endcase
            if (frame_file == 0) begin
                $display("FAIL: could not open frame output file %0d", frame_number);
                $finish;
            end
            $fwrite(frame_file, "P2\n%0d %0d\n255\n", WIDTH, HEIGHT);
            for (y = 0; y < HEIGHT; y = y + 1) begin
                for (x = 0; x < WIDTH; x = x + 1) begin
                    pixel_x = x;
                    pixel_y = y;
                    #1;
                    if (pixel_on)
                        $fwrite(frame_file, "0 ");
                    else
                        $fwrite(frame_file, "255 ");
                end
                $fwrite(frame_file, "\n");
            end
            $fclose(frame_file);
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        write_en = 1'b0;
        write_addr = 32'b0;
        write_data = 32'b0;
        pixel_x = 6'b0;
        pixel_y = 5'b0;
        #20;
        resetn = 1'b1;
        for (frame = 0; frame < 4; frame = frame + 1)
            write_frame(frame);
        $display("PASS: generated 4 monochrome demo frames (%0dx%0d)", WIDTH, HEIGHT);
        $finish;
    end
endmodule
