// Verilator + raylib harness for rtl/mips_pipeline.v.
//
// The CPU's instruction and data SRAM interfaces are modelled here in C++.
// A region of the data address space is memory-mapped to the raylib frontend:
//
//   0x00000000 - 0x0000ffff : general data RAM
//   0x00010000              : 64x32 framebuffer, one 32-bit word per pixel
//   0x00020000              : input register (bit0 = up, bit1 = down)
//   0x00020004              : free-running cycle counter
//   0x00020008              : frame-done handshake (write ends the frame)
//
// The CPU is executed until it writes the frame-done register, then the
// framebuffer is uploaded to a texture and raylib renders one 60 Hz frame.

#include "Vmips_pipeline.h"
#include "verilated.h"

#include <raylib.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

static constexpr uint32_t IMEM_BASE = 0xbfc00000u;
static constexpr uint32_t IMEM_BYTES = 1u << 16;
static constexpr uint32_t RAM_WORDS = 1u << 14;  // 64 KiB
static constexpr uint32_t FB_BASE = 0x00010000u;
static constexpr int FB_WIDTH = 64;
static constexpr int FB_HEIGHT = 32;
static constexpr uint32_t INPUT_ADDR = 0x00020000u;
static constexpr uint32_t COUNTER_ADDR = 0x00020004u;
static constexpr uint32_t FRAME_ADDR = 0x00020008u;
static constexpr int SCALE = 14;
static constexpr uint64_t MAX_CYCLES_PER_FRAME = 4'000'000;

static std::vector<uint32_t> imem(IMEM_BYTES / 4, 0);
static std::vector<uint32_t> ram(RAM_WORDS, 0);
static std::vector<uint32_t> framebuffer(FB_WIDTH * FB_HEIGHT, 0);
static uint32_t input_register = 0;
static uint64_t cycle_count = 0;
static bool frame_done = false;
static bool trace = false;

static bool load_program(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        std::fprintf(stderr, "error: cannot open program '%s'\n", path.c_str());
        return false;
    }

    const bool is_binary = path.size() >= 4 &&
                           path.compare(path.size() - 4, 4, ".bin") == 0;
    if (is_binary) {
        // Raw big-endian MIPS image, loaded at the reset vector.
        std::vector<unsigned char> bytes((std::istreambuf_iterator<char>(file)),
                                         std::istreambuf_iterator<char>());
        if (bytes.size() % 4 != 0) {
            std::fprintf(stderr, "error: '%s' is not a multiple of 4 bytes\n",
                         path.c_str());
            return false;
        }
        const size_t words = bytes.size() / 4;
        if (words > imem.size()) {
            std::fprintf(stderr, "error: program exceeds instruction memory\n");
            return false;
        }
        for (size_t i = 0; i < words; i++) {
            imem[i] = (static_cast<uint32_t>(bytes[i * 4 + 0]) << 24) |
                      (static_cast<uint32_t>(bytes[i * 4 + 1]) << 16) |
                      (static_cast<uint32_t>(bytes[i * 4 + 2]) << 8) |
                      (static_cast<uint32_t>(bytes[i * 4 + 3]));
        }
        return true;
    }

    // Plain text file with one 32-bit hex word per line.
    size_t index = 0;
    std::string line;
    while (std::getline(file, line)) {
        size_t comment = line.find_first_of("#/");
        if (comment != std::string::npos)
            line.resize(comment);
        size_t begin = line.find_first_not_of(" \t\r\n");
        if (begin == std::string::npos)
            continue;
        size_t end = line.find_last_not_of(" \t\r\n");
        line = line.substr(begin, end - begin + 1);
        if (line[0] == '@') {
            index = std::strtoul(line.c_str() + 1, nullptr, 16) / 4;
            continue;
        }
        if (index >= imem.size()) {
            std::fprintf(stderr, "error: program exceeds instruction memory\n");
            return false;
        }
        imem[index++] = std::strtoul(line.c_str(), nullptr, 16);
    }
    return true;
}

static uint32_t read_instruction(uint32_t address) {
    if (address >= IMEM_BASE && address < IMEM_BASE + IMEM_BYTES)
        return imem[(address - IMEM_BASE) >> 2];
    return 0;
}

static uint32_t read_data(uint32_t address) {
    if (address < RAM_WORDS * 4)
        return ram[address >> 2];
    if (address >= FB_BASE && address < FB_BASE + FB_WIDTH * FB_HEIGHT * 4)
        return framebuffer[(address - FB_BASE) >> 2];
    if (address == INPUT_ADDR)
        return input_register;
    if (address == COUNTER_ADDR)
        return static_cast<uint32_t>(cycle_count);
    return 0;
}

static void write_data(uint32_t address, uint32_t data) {
    if (address < RAM_WORDS * 4) {
        ram[address >> 2] = data;
        return;
    }
    if (address >= FB_BASE && address < FB_BASE + FB_WIDTH * FB_HEIGHT * 4) {
        framebuffer[(address - FB_BASE) >> 2] = data;
        return;
    }
    if (address == FRAME_ADDR)
        frame_done = true;
}

// One rising clock edge. Memory reads are combinational, memory writes are
// captured from the pre-edge bus values, mirroring the Verilog testbenches.
static void step(Vmips_pipeline* top) {
    top->clk = 0;
    top->eval();
    top->inst_sram_rdata = read_instruction(top->inst_sram_addr);
    top->data_sram_rdata = read_data(top->data_sram_addr);
    top->eval();

    const uint8_t write_enable = top->data_sram_wen;
    const uint32_t write_address = top->data_sram_addr;
    const uint32_t write_value = top->data_sram_wdata;

    top->clk = 1;
    top->eval();
    if (write_enable)
        write_data(write_address, write_value);
    top->clk = 0;
    top->eval();

    if (trace && (write_enable || cycle_count % 20000 == 0)) {
        std::printf("cyc=%3llu fetch=%08x inst=%08x wb_pc=%08x we=%d dst=%2u "
                    "data_we=%x data_addr=%08x data_w=%08x\n",
                    static_cast<unsigned long long>(cycle_count),
                    top->inst_sram_addr, top->inst_sram_rdata, top->debug_wb_pc,
                    top->debug_wb_rf_wen != 0, top->debug_wb_rf_wnum,
                    static_cast<unsigned>(top->data_sram_wen),
                    top->data_sram_addr, top->data_sram_wdata);
    }
    cycle_count++;
}

static uint64_t run_frame(Vmips_pipeline* top, bool& stalled) {
    frame_done = false;
    uint64_t executed = 0;
    while (!frame_done && executed < MAX_CYCLES_PER_FRAME) {
        step(top);
        executed++;
    }
    stalled = !frame_done;
    return executed;
}

static void print_frame(int number) {
    std::printf("---- frame %d ----\n", number);
    for (int y = 0; y < FB_HEIGHT; y++) {
        for (int x = 0; x < FB_WIDTH; x++)
            std::putchar(framebuffer[y * FB_WIDTH + x] ? '#' : '.');
        std::putchar('\n');
    }
}

static void locate_ball(int& ball_x, int& ball_y) {
    ball_x = -1;
    ball_y = -1;
    for (int y = 1; y < FB_HEIGHT - 1; y++) {
        for (int x = 0; x < FB_WIDTH; x++) {
            if (x == 2 || x == 61 || x == 32)
                continue;
            if (framebuffer[y * FB_WIDTH + x]) {
                ball_x = x;
                ball_y = y;
            }
        }
    }
}

static void paddle_span(int column, int& top, int& bottom) {
    top = -1;
    bottom = -1;
    for (int y = 1; y < FB_HEIGHT - 1; y++) {
        if (framebuffer[y * FB_WIDTH + column]) {
            if (top < 0)
                top = y;
            bottom = y;
        }
    }
}

static int run_headless(Vmips_pipeline* top, int frames, bool scripted) {
    bool stalled = false;
    for (int frame = 0; frame < frames; frame++) {
        input_register = 0;
        if (scripted) {
            if (frame >= 10 && frame < 50)
                input_register |= 1u;   // hold up
            if (frame >= 60 && frame < 100)
                input_register |= 2u;   // hold down
        }
        const uint64_t cycles = run_frame(top, stalled);
        if (stalled) {
            std::fprintf(stderr, "error: frame %d did not finish\n", frame);
            return 1;
        }
        int lit = 0;
        for (uint32_t pixel : framebuffer)
            lit += pixel ? 1 : 0;
        int ball_x, ball_y, player_top, player_bottom, ai_top, ai_bottom;
        locate_ball(ball_x, ball_y);
        paddle_span(2, player_top, player_bottom);
        paddle_span(61, ai_top, ai_bottom);
        std::printf("frame %3d: cycles=%6llu lit=%4d ball=(%2d,%2d) "
                    "player=[%2d..%2d] ai=[%2d..%2d]\n",
                    frame, static_cast<unsigned long long>(cycles), lit,
                    ball_x, ball_y, player_top, player_bottom, ai_top, ai_bottom);
        if (frame % 30 == 0 || frame == frames - 1)
            print_frame(frame);
    }
    return 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    std::string program = "build/pong.bin";
    int headless_frames = -1;
    bool scripted = false;
    for (int i = 1; i < argc; i++) {
        if (std::strcmp(argv[i], "--headless") == 0) {
            headless_frames = (i + 1 < argc) ? std::atoi(argv[++i]) : 60;
        } else if (std::strcmp(argv[i], "--trace") == 0) {
            trace = true;
        } else if (std::strcmp(argv[i], "--script") == 0) {
            scripted = true;
        } else {
            program = argv[i];
        }
    }
    if (!load_program(program))
        return 1;

    Vmips_pipeline* top = new Vmips_pipeline;

    top->resetn = 0;
    for (int i = 0; i < 8; i++)
        step(top);
    top->resetn = 1;

    if (headless_frames >= 0) {
        const int result = run_headless(top, headless_frames, scripted);
        delete top;
        return result;
    }

    InitWindow(FB_WIDTH * SCALE, FB_HEIGHT * SCALE, "MIPS Pong - mips_pipeline + Verilator + raylib");
    SetTargetFPS(60);

    unsigned char pixels[FB_WIDTH * FB_HEIGHT * 4];
    Image image = {pixels, FB_WIDTH, FB_HEIGHT, 1, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8};
    Texture2D texture = LoadTextureFromImage(image);
    SetTextureFilter(texture, TEXTURE_FILTER_POINT);

    bool warned = false;
    while (!WindowShouldClose()) {
        input_register = 0;
        if (IsKeyDown(KEY_W) || IsKeyDown(KEY_UP))
            input_register |= 1u;
        if (IsKeyDown(KEY_S) || IsKeyDown(KEY_DOWN))
            input_register |= 2u;

        frame_done = false;
        uint64_t executed = 0;
        while (!frame_done && executed < MAX_CYCLES_PER_FRAME) {
            step(top);
            executed++;
        }
        if (!frame_done && !warned) {
            std::fprintf(stderr, "warning: frame took more than %llu cycles, "
                                 "the program may be stuck\n",
                         static_cast<unsigned long long>(MAX_CYCLES_PER_FRAME));
            warned = true;
        }

        for (int i = 0; i < FB_WIDTH * FB_HEIGHT; i++) {
            const unsigned char value = framebuffer[i] ? 255 : 0;
            pixels[i * 4 + 0] = value;
            pixels[i * 4 + 1] = value;
            pixels[i * 4 + 2] = value;
            pixels[i * 4 + 3] = 255;
        }
        UpdateTexture(texture, pixels);

        BeginDrawing();
        ClearBackground(BLACK);
        DrawTextureEx(texture, {0.0f, 0.0f}, 0.0f, static_cast<float>(SCALE), WHITE);
        DrawFPS(6, 14);
        EndDrawing();
    }

    delete top;
    CloseWindow();
    return 0;
}
