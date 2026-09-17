#!/usr/bin/env bash
#
# build_asm.sh - assemble a MIPS program for the pipeline CPU and print the
# Verilog instruction-memory case lines.
#
# The program is linked at the reset vector 0xbfc00000 (so `j` instructions are
# relocated correctly) and emitted as 32-bit big-endian words, ready to paste
# into a testbench's `case (inst_sram_addr)`.
#
# Usage:  scripts/build_asm.sh programs/fibonacci.s
#
set -euo pipefail

src=${1:?usage: build_asm.sh <file.s>}
out="/tmp/mips_asm_$(basename "${src%.s}")"
mkdir -p "$out"

clang --target=mips-unknown-elf -march=mips1 -mabi=32 -mno-abicalls \
      -c "$src" -o "$out/prog.o"
ld.lld -Ttext=0xbfc00000 -e main "$out/prog.o" -o "$out/prog.elf"
llvm-objcopy -O binary --only-section=.text "$out/prog.elf" "$out/prog.bin"

python3 - "$out/prog.bin" <<'PY'
import sys
data = open(sys.argv[1], "rb").read()
for i in range(0, len(data), 4):
    word = int.from_bytes(data[i:i + 4], "big")
    print(f"            RESET_PC + 32'd{i}: inst_sram_rdata = 32'h{word:08x};")
PY
