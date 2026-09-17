// Pong for pipeline_cpu, compiled with clang's MIPS backend.
//
// The CPU's data address space is memory-mapped by sim_main.cpp:
//
//   0x00000000 - 0x0000ffff : general data RAM (also holds .data/.bss/stack)
//   0x00010000              : framebuffer base, 64x32 pixels, one 32-bit
//                             word per pixel (0 = off, non-zero = on)
//   0x00020000              : input register, bit 0 = up, bit 1 = down
//   0x00020004              : free-running cycle counter (pseudo random)
//   0x00020008              : frame-done handshake, any write ends the frame
//
// Controls: W / Up arrow moves the left paddle up, S / Down moves it down.
// The right paddle is driven by simple AI.

#define WIDTH 64
#define HEIGHT 32
#define PADDLE_H 6
#define PADDLE_MAX_Y (HEIGHT - PADDLE_H)

#define FB      ((volatile unsigned int *)0x00010000u)
#define INPUT   (*(volatile unsigned int *)0x00020000u)
#define COUNTER (*(volatile unsigned int *)0x00020004u)
#define FRAME   (*(volatile unsigned int *)0x00020008u)

static int ball_x, ball_y, ball_dx, ball_dy;
static int player_y, ai_y;

static void draw_pixel(int x, int y) {
    FB[(y << 6) + x] = 1;
}

static void draw_paddle(int x, int y) {
    int i;
    for (i = 0; i < PADDLE_H; i++)
        draw_pixel(x, y + i);
}

static void draw_walls(void) {
    int i;
    for (i = 0; i < WIDTH; i++) {
        draw_pixel(i, 0);
        draw_pixel(i, HEIGHT - 1);
    }
    for (i = 1; i < HEIGHT - 1; i += 2)
        draw_pixel(WIDTH / 2, i);
}

static void reset_ball(void) {
    ball_x = WIDTH / 2;
    ball_y = HEIGHT / 2;
    ball_dx = (COUNTER & 1) ? 1 : -1;
    ball_dy = (COUNTER & 2) ? 1 : -1;
}

static void clear_playfield(void) {
    int i;
    volatile unsigned int *p = FB + WIDTH;   // start at row 1, keep the walls
    for (i = 0; i < (HEIGHT - 2) * WIDTH; i++)
        p[i] = 0;
}

static void step_ball(void) {
    ball_x += ball_dx;
    ball_y += ball_dy;

    if (ball_y < 0) {
        ball_y = 0;
        ball_dy = -ball_dy;
    } else if (ball_y >= HEIGHT) {
        ball_y = HEIGHT - 1;
        ball_dy = -ball_dy;
    }

    if (ball_dx < 0) {
        if (ball_x <= 3) {
            if (ball_y >= player_y && ball_y < player_y + PADDLE_H) {
                ball_x = 4;
                ball_dx = 1;
                ball_dy = (ball_y < player_y + PADDLE_H / 2) ? -1 : 1;
            } else if (ball_x < 0) {
                reset_ball();
            }
        }
    } else {
        if (ball_x >= 60) {
            if (ball_y >= ai_y && ball_y < ai_y + PADDLE_H) {
                ball_x = 59;
                ball_dx = -1;
                ball_dy = (ball_y < ai_y + PADDLE_H / 2) ? -1 : 1;
            } else if (ball_x >= WIDTH) {
                reset_ball();
            }
        }
    }
}

int main(void) {
    player_y = 13;
    ai_y = 13;
    ball_x = WIDTH / 2;
    ball_y = HEIGHT / 2;
    ball_dx = 1;
    ball_dy = 1;

    draw_walls();

    for (;;) {
        // volatile so the compiler emits a full-word load of the input port
        volatile unsigned int in = INPUT;
        if ((in & 1) && player_y > 0)
            player_y--;
        if ((in & 2) && player_y < PADDLE_MAX_Y)
            player_y++;

        int target = ball_y - PADDLE_H / 2;
        if (ai_y < target)
            ai_y++;
        else if (ai_y > target)
            ai_y--;
        if (ai_y < 0)
            ai_y = 0;
        if (ai_y > PADDLE_MAX_Y)
            ai_y = PADDLE_MAX_Y;

        step_ball();

        clear_playfield();
        draw_paddle(2, player_y);
        draw_paddle(61, ai_y);
        draw_pixel(ball_x, ball_y);

        FRAME = 0;
    }
}
