# Verilator + raylib frontend for rtl/mips_pipeline.v.
#
# The pong program is written in C and compiled for MIPS-I with clang's
# integrated MIPS backend, linked with lld, and turned into a raw binary
# that sim_main.cpp loads at the CPU's reset vector.

VERILATOR ?= verilator
CLANG     ?= clang
# LD is a built-in make variable (defaults to "ld"), so it must be set directly.
LD        := ld.lld
OBJDUMP   ?= llvm-objdump
OBJCOPY   ?= llvm-objcopy

RTL_DIR     := ../rtl
RTL_SOURCES := \
	$(RTL_DIR)/mips_pipeline.v \
	$(RTL_DIR)/pc.v \
	$(RTL_DIR)/control.v \
	$(RTL_DIR)/alu_control.v \
	$(RTL_DIR)/alu.v \
	$(RTL_DIR)/regfile.v \
	$(RTL_DIR)/sign_extend.v \
	$(RTL_DIR)/shift_left2.v \
	$(RTL_DIR)/hazard.v \
	$(RTL_DIR)/forward.v

RAYLIB_CFLAGS := $(shell pkg-config --cflags raylib)
RAYLIB_LIBS   := $(shell pkg-config --libs raylib)

# -march=mips1 keeps codegen close to the CPU's ISA, -G0 disables gp-relative
# addressing, and -O0 keeps branch delay slots filled with nops (the CPU
# flushes the delay slot instead of executing it).
CLANG_TARGET := --target=mips-unknown-elf
CLANG_FLAGS  := $(CLANG_TARGET) -march=mips1 -mabi=32 -O0 -G0 \
                -ffreestanding -fno-builtin -fno-pic -mno-abicalls \
                -fno-stack-protector -Wall

BUILD_DIR := build
OBJ_DIR   := obj_dir
PROGRAM   := $(BUILD_DIR)/pong.bin
ELF       := $(BUILD_DIR)/pong.elf
TARGET    := $(OBJ_DIR)/pong

.PHONY: all run disasm clean

all: $(TARGET) $(PROGRAM)

$(BUILD_DIR)/start.o: start.S
	@mkdir -p $(BUILD_DIR)
	$(CLANG) $(CLANG_FLAGS) -c $< -o $@

$(BUILD_DIR)/pong.o: pong.c
	@mkdir -p $(BUILD_DIR)
	$(CLANG) $(CLANG_FLAGS) -c $< -o $@

$(ELF): $(BUILD_DIR)/start.o $(BUILD_DIR)/pong.o link.ld
	$(LD) -T link.ld $(BUILD_DIR)/start.o $(BUILD_DIR)/pong.o -o $@

$(PROGRAM): $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $< $@
	@printf 'program: %s (%s bytes)\n' '$@' "$$(stat -c %s $@)"

$(TARGET): $(RTL_SOURCES) sim_main.cpp
	$(VERILATOR) --cc $(RTL_SOURCES) --exe sim_main.cpp \
		--top-module mips_pipeline --Mdir $(OBJ_DIR) -o pong \
		--build -j \
		-Wno-fatal -O3 \
		-CFLAGS "$(RAYLIB_CFLAGS) -O2" \
		-LDFLAGS "$(RAYLIB_LIBS)"

run: all
	./$(TARGET) $(PROGRAM)

disasm: $(ELF)
	$(OBJDUMP) -d $<

clean:
	rm -rf $(OBJ_DIR) $(BUILD_DIR)
