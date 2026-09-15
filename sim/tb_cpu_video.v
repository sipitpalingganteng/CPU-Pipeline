`timescale 1ns / 1ps

module tb_cpu_video;
    localparam [31:0] RESET_PC = 32'hbfc00000;
    localparam [31:0] VIDEO_FRAME_ADDR = 32'h00001000;
    localparam integer WIDTH = 64;
    localparam integer HEIGHT = 48;

    reg clk;
    reg resetn;
    wire        inst_sram_en;
    wire [3:0]  inst_sram_wen;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    reg  [31:0] inst_sram_rdata;
    wire        data_sram_en;
    wire [3:0]  data_sram_wen;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire [31:0] data_sram_rdata;
    wire [31:0] debug_wb_pc;
    wire [3:0]  debug_wb_rf_wen;
    wire [4:0]  debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;
    wire [4:0]  frame_index;
    reg  [4:0]  export_frame_index;
    reg  [5:0]  export_pixel_x;
    reg  [5:0]  export_pixel_y;
    wire        export_pixel_on;
    integer write_count;
    integer seen_frame [0:19];
    reg [5:0] pixel_x;
    reg [4:0] pixel_y;
    wire pixel_on;
    integer frame_file;
    integer frame_number;
    integer x;
    integer y;

    pipeline_cpu cpu (
        .clk(clk), .resetn(resetn),
        .inst_sram_en(inst_sram_en), .inst_sram_wen(inst_sram_wen),
        .inst_sram_addr(inst_sram_addr), .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .data_sram_en(data_sram_en), .data_sram_wen(data_sram_wen),
        .data_sram_addr(data_sram_addr), .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata),
        .debug_wb_pc(debug_wb_pc), .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    bad_apple_video_peripheral #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) video (
        .clk(clk),
        .resetn(resetn),
        .write_en(data_sram_wen != 4'b0000),
        .write_addr(data_sram_addr),
        .write_data(data_sram_wdata),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_on(pixel_on),
        .frame_index(frame_index)
    );

    bad_apple_frame_rom export_rom (
        .frame_index(export_frame_index),
        .pixel_x(export_pixel_x),
        .pixel_y(export_pixel_y),
        .pixel_on(export_pixel_on)
    );

    assign data_sram_rdata = 32'b0;

    always @(*) begin
        case (inst_sram_addr)
            RESET_PC + 32'd0:  inst_sram_rdata = 32'h24080000; // addiu t0, zero, 0
            RESET_PC + 32'd4:  inst_sram_rdata = 32'hac081000; // sw t0, 0x1000(zero)
            RESET_PC + 32'd8:  inst_sram_rdata = 32'h24080001; // addiu t0, zero, 1
            RESET_PC + 32'd12: inst_sram_rdata = 32'hac081000; // sw t0, 0x1000(zero)
            RESET_PC + 32'd16: inst_sram_rdata = 32'h24080002; // addiu t0, zero, 2
            RESET_PC + 32'd20: inst_sram_rdata = 32'hac081000; // sw t0, 0x1000(zero)
            RESET_PC + 32'd24: inst_sram_rdata = 32'h24080003; // addiu t0, zero, 3
            RESET_PC + 32'd28: inst_sram_rdata = 32'hac081000; // sw t0, 0x1000(zero)
            RESET_PC + 32'd32: inst_sram_rdata = 32'h24080004; // addiu t0, zero, 4
            RESET_PC + 32'd36: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd40: inst_sram_rdata = 32'h24080005;
            RESET_PC + 32'd44: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd48: inst_sram_rdata = 32'h24080006;
            RESET_PC + 32'd52: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd56: inst_sram_rdata = 32'h24080007;
            RESET_PC + 32'd60: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd64: inst_sram_rdata = 32'h24080008;
            RESET_PC + 32'd68: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd72: inst_sram_rdata = 32'h24080009;
            RESET_PC + 32'd76: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd80: inst_sram_rdata = 32'h2408000a;
            RESET_PC + 32'd84: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd88: inst_sram_rdata = 32'h2408000b;
            RESET_PC + 32'd92: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd96: inst_sram_rdata = 32'h2408000c;
            RESET_PC + 32'd100: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd104: inst_sram_rdata = 32'h2408000d;
            RESET_PC + 32'd108: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd112: inst_sram_rdata = 32'h2408000e;
            RESET_PC + 32'd116: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd120: inst_sram_rdata = 32'h2408000f;
            RESET_PC + 32'd124: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd128: inst_sram_rdata = 32'h24080010;
            RESET_PC + 32'd132: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd136: inst_sram_rdata = 32'h24080011;
            RESET_PC + 32'd140: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd144: inst_sram_rdata = 32'h24080012;
            RESET_PC + 32'd148: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd152: inst_sram_rdata = 32'h24080013;
            RESET_PC + 32'd156: inst_sram_rdata = 32'hac081000;
            RESET_PC + 32'd160: inst_sram_rdata = 32'h08000029; // loop
            RESET_PC + 32'd164: inst_sram_rdata = 32'h00000000;
            default:           inst_sram_rdata = 32'h00000000;
        endcase
    end

    task export_frame;
        input integer number;
        begin
            frame_file = 0;
            case (number)
                0:  frame_file = $fopen("cpu_video_frame_00.pgm", "w");
                1:  frame_file = $fopen("cpu_video_frame_01.pgm", "w");
                2:  frame_file = $fopen("cpu_video_frame_02.pgm", "w");
                3:  frame_file = $fopen("cpu_video_frame_03.pgm", "w");
                4:  frame_file = $fopen("cpu_video_frame_04.pgm", "w");
                5:  frame_file = $fopen("cpu_video_frame_05.pgm", "w");
                6:  frame_file = $fopen("cpu_video_frame_06.pgm", "w");
                7:  frame_file = $fopen("cpu_video_frame_07.pgm", "w");
                8:  frame_file = $fopen("cpu_video_frame_08.pgm", "w");
                9:  frame_file = $fopen("cpu_video_frame_09.pgm", "w");
                10: frame_file = $fopen("cpu_video_frame_10.pgm", "w");
                11: frame_file = $fopen("cpu_video_frame_11.pgm", "w");
                12: frame_file = $fopen("cpu_video_frame_12.pgm", "w");
                13: frame_file = $fopen("cpu_video_frame_13.pgm", "w");
                14: frame_file = $fopen("cpu_video_frame_14.pgm", "w");
                15: frame_file = $fopen("cpu_video_frame_15.pgm", "w");
                16: frame_file = $fopen("cpu_video_frame_16.pgm", "w");
                17: frame_file = $fopen("cpu_video_frame_17.pgm", "w");
                18: frame_file = $fopen("cpu_video_frame_18.pgm", "w");
                19: frame_file = $fopen("cpu_video_frame_19.pgm", "w");
            endcase
            if (frame_file != 0) begin
                $fwrite(frame_file, "P2\n%0d %0d\n255\n", WIDTH, HEIGHT);
                export_frame_index = number;
                for (y = 0; y < HEIGHT; y = y + 1) begin
                    for (x = 0; x < WIDTH; x = x + 1) begin
                        export_pixel_x = x;
                        export_pixel_y = y;
                        #1;
                        $fwrite(frame_file, "%0d ", export_pixel_on ? 0 : 255);
                    end
                    $fwrite(frame_file, "\n");
                end
                $fclose(frame_file);
            end
        end
    endtask

    always @(posedge clk) begin
        if (data_sram_wen != 4'b0000 &&
            data_sram_addr == VIDEO_FRAME_ADDR) begin
            if (write_count < 20) begin
                seen_frame[write_count] = data_sram_wdata[4:0];
                write_count = write_count + 1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        pixel_x = 6'b0;
        pixel_y = 5'b0;
        export_frame_index = 5'b0;
        export_pixel_x = 6'b0;
        export_pixel_y = 6'b0;
        write_count = 0;
        #40;
        resetn = 1'b1;
        #70000;
        if (write_count != 20 || frame_index !== 5'd19) begin
            $display("FAIL: CPU frame writes=%0d final_frame=%0d", write_count, frame_index);
        end
        else begin
            for (frame_number = 0; frame_number < 20; frame_number = frame_number + 1)
                $display("CPU selected video frame %0d", seen_frame[frame_number]);
            for (frame_number = 0; frame_number < 20; frame_number = frame_number + 1)
                export_frame(frame_number);
            $display("PASS: CPU selected and exported video frames 0 through 19");
        end
        $finish;
    end
endmodule
