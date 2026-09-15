import argparse
from pathlib import Path
import re


def read_pgm(path):
    data = path.read_bytes()
    tokens = []
    position = 0
    while len(tokens) < 4:
        while position < len(data) and data[position] in b" \t\r\n":
            position += 1
        if position < len(data) and data[position] == ord("#"):
            newline = data.find(b"\n", position)
            position = len(data) if newline < 0 else newline + 1
            continue
        end = position
        while end < len(data) and data[end] not in b" \t\r\n":
            end += 1
        tokens.append(data[position:end].decode("ascii"))
        position = end

    if tokens[0] not in ("P2", "P5"):
        raise ValueError(f"{path} is not a supported PGM file")
    width = int(tokens[1])
    height = int(tokens[2])
    max_value = int(tokens[3])
    while position < len(data) and data[position] in b" \t\r\n":
        position += 1
    if tokens[0] == "P5":
        pixels = list(data[position:position + width * height])
    else:
        pixels = [int(value) for value in data[position:].split()]
    if len(pixels) != width * height:
        raise ValueError(f"{path} has {len(pixels)} pixels, expected {width * height}")
    return width, height, max_value, pixels


def packed_hex(pixels, max_value):
    value = 0
    for index, pixel in enumerate(pixels):
        if pixel < max_value // 2:
            value |= 1 << index
    digits = (len(pixels) + 3) // 4
    return f"{value:0{digits}x}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("frames_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    frame_paths = sorted(args.frames_dir.glob("frame_*.pgm"))
    if not frame_paths:
        raise SystemExit("No frame_*.pgm files found")

    frames = []
    width = height = None
    for frame_path in frame_paths:
        frame_width, frame_height, max_value, pixels = read_pgm(frame_path)
        if width is None:
            width, height = frame_width, frame_height
        if (frame_width, frame_height) != (width, height):
            raise ValueError("All frames must have the same dimensions")
        frames.append(packed_hex(pixels, max_value))

    if width > 64 or height > 64:
        raise ValueError("Generated module supports dimensions up to 64x64")

    x_bits = max(1, (width - 1).bit_length())
    y_bits = max(1, (height - 1).bit_length())
    frame_bits = max(1, (len(frames) - 1).bit_length())
    vector_width = width * height

    lines = [
        f"module bad_apple_frame_rom #(",
        f"    parameter integer WIDTH = {width},",
        f"    parameter integer HEIGHT = {height},",
        f"    parameter integer FRAME_COUNT = {len(frames)}",
        f") (",
        f"    input [{frame_bits - 1}:0] frame_index,",
        f"    input [{x_bits - 1}:0] pixel_x,",
        f"    input [{y_bits - 1}:0] pixel_y,",
        f"    output pixel_on",
        f");",
        f"    reg [{vector_width - 1}:0] frame_mem [0:FRAME_COUNT-1];",
        f"    initial begin",
    ]
    for index, frame_hex in enumerate(frames):
        lines.append(f"        frame_mem[{index}] = {vector_width}'h{frame_hex};")
    lines.extend([
        "    end",
        "",
        "    assign pixel_on = (frame_index < FRAME_COUNT) &&",
        "                      (pixel_x < WIDTH) && (pixel_y < HEIGHT) &&",
        "                      frame_mem[frame_index][pixel_y * WIDTH + pixel_x];",
        "endmodule",
        "",
    ])
    args.output.write_text("\n".join(lines), encoding="ascii")
    print(f"Generated {args.output} from {len(frames)} frames at {width}x{height}")


if __name__ == "__main__":
    main()
