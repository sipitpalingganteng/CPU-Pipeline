// final.typ - Final report for the MIPS CPU on FPGA project
//
// Continuation of midterm.typ. The single-cycle design from the midterm has
// been extended into a five-stage pipeline, keeping the same building blocks
// (pc, control, alu_control, regfile, sign_extend, shift_left2, alu, imem,
// dmem) and adding pipeline registers, forwarding and a hazard unit.
//
// Compile:  typst compile final.typ

#import "@preview/touying:0.6.1": *
#import themes.metropolis: *

#import "@preview/numbly:0.1.0": numbly

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer: self => self.info.institution,
  config-info(
    title: [MIPS CPU on FPGA - Final Report],
    author: [Group 5 - 汤铁峰 1820232065, 邝振锋 1820232069, 蔡立根 1820232081],
    date: datetime.today(),
    institution: [计算机组成原理课程设计],
  ),
)

#set heading(numbering: numbly("{1}.", default: "1.1"))
#set figure(numbering: "1")

// Reserve space for a screenshot until the real capture is inserted.
#let placeholder(label, caption, height: 4.2cm) = figure(
  block(
    width: 100%,
    height: height,
    fill: luma(243),
    radius: 3pt,
    stroke: (paint: luma(170), dash: "dashed", thickness: 0.8pt),
    align(center)[#text(fill: gray, weight: "medium")[Placeholder — #label]],
  ),
  caption: caption,
)

#title-slide()

// ---------------------------------------------------------------- Outline
= Outline <touying:hidden>

#outline(title: none, indent: 1em, depth: 1)

// ====================================================== 1. What we learned
= Preparation

== Preparation

- MIPS canonical 5-stage pipeline
#figure(
  image("img/mips_pipelined_ppt.png"),
  caption: [Pipeline Schematic (from PPT)]
)
- Pipeline hazards: structural, data, and control
#figure(
  image("img/data_hazard.png"),
  caption: [Data Dependency: Data Hazard Example (https://www.youtube.com/@prof.dr.benh.juurlink5459)]
)
#figure(
  image("img/forwarding_diagram.png"),
  caption: [Forwarding: Data Hazard Solution (https://www.youtube.com/@prof.dr.benh.juurlink5459)]
)


// ============================================= 2. Five-stage CPU now
= Final Implementation

== Overview of our design

- A *larger* MIPS subset, now enough for clang-generated code:
  R-type (`addu subu slt sltu and or xor nor sll srl sra jr`),
  I-type (`addiu lui lw sw beq bne slti andi ori blez bgez`),
  J-type (`j jal`). In total, *25* instructions.
- Five stages — #text(weight: "bold")[IF, ID, EX, MEM, WB] — with a new
  instruction starting every cycle, so the CPI is close to 1.
- Pipeline registers `IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB` carry the data
  *and the control bits* forward to the later stages.
- Separate instruction and data SRAM (Harvard-style) — no structural hazards.
- Branches are resolved in ID and the following instruction is flushed, so
  there is no delay slot; `jal` links `PC + 4`.

The datapath is the single-cycle one, cut into stages:

#align(center)[
  #block(width: 92%, inset: 6pt, fill: luma(248), radius: 3pt)[
    #set text(size: 18.5pt)
    `IF -> ID -> EX -> MEM -> WB`
    #linebreak()
    `PC -> imem -> control/regfile -> alu -> (dmem) -> write-back`
  ]
]

== Pipeline registers and data flow

- `IF/ID` carries `PC` and the fetched instruction into decode.
- `ID/EX` carries the register values, immediates, destination and control
  signals; the ALU op is pre-decoded here.
- `EX/MEM` carries the ALU result and the store data; the load data is
  captured at this boundary because the SRAM read is combinational.
- `MEM/WB` carries the final result into the register-file write-back.
- Valid bits and `allowin` signals let a stage stall (load-use) or flush
  (branch) without disturbing the stages behind it.

#figure(
  image("img/pipeline_rtl.png"),
  caption: [Vivado RTL analysis]
)

== Module breakdown

#table(
  columns: (0.9fr, 3.5fr),
  align: (left, left),
  inset: (x: 6pt, y: 2.5pt),
  stroke: 0.4pt + luma(200),
  [#text(weight: "bold")[module]],
  [#text(weight: "bold")[responsibility]],
  [`pc`], [Program counter (IF), reset + enable],
  [`imem`], [Instruction SRAM, word-indexed (Harvard)],
  [`control`], [decodes the ID instruction → control signals + branch type],
  [`alu_control`], [decoded instruction → 12-bit one-hot ALU operation],
  [`regfile`], [32 × 32 regs, 2 read / 1 write port, `$zero` masked],
  [`sign_extend`], [16 → 32-bit sign extension of immediates],
  [`shift_left2`], [`<<2` used for branch offsets and jump targets],
  [`alu`], [add / sub / and / or / xor / nor / slt / sltu / shifts / lui],
  [`forward`], [EX/MEM → ID forwarding selects],
  [`hazard`], [load-use stall: freeze IF and ID for one cycle],
  [`dmem`], [Data SRAM, sync write / comb. read],
  [`mips_pipeline`], [top-level: wires the stages and pipeline registers],
)

== Hazard handling

- *Data hazards:* `forward` selects the freshest operand from the EX result or
  from MEM/WB, so most dependencies cost no cycles.
- *Load-use hazard:* a load result is not ready in EX, so `hazard` stalls IF and
  ID for one cycle and the value is then forwarded from MEM/WB.
- *Control hazards:* `beq/bne/blez/bgez/j/jal/jr` are resolved in ID; the
  instruction fetched behind them is flushed (no delay slot).

#figure(
  image("img/waveform_load_use.png"),
  caption: [Waveform of a load-use stall]
)
#figure(
  image("img/waveform_branch.png"),
  caption: [Waveform of when a branch is taken]
)
== Verification: the test programs

The core is exercised by directed testbenches and a compiler-generated program:

```text
tb_pipeline_cpu  hazard + forwarding (addu / sw / lw / subu / and / or / xor)
tb_branch_cpu    branch flush and target (beq)
tb_jal_cpu       subroutine link / return (jal + jr, links PC + 4)
tb_isa_ext       slti / andi / ori / j / blez / bgez + load capture
tb_bubble_sort   bubble sorts an 8-word array in data memory
tb_fibonacci     stores fib(0..9) iteratively
```
Program was written in MIPS asm and then compiled to machine code with MARS assembler.

Performance counters are exposed for every run.

#figure(
  image("img/tb_branch_cpu.png"),
  caption: [Example result: tb_branch_cpu.v]
)
#figure(
  image("img/bubble_sort.png"),
  caption: [Example result: tb_bubble_sort.v]
)
#figure(
  image("img/fibonacci.png"),
  caption: [Example result: tb_fibonacci.v]
)

== Performance

The core exposes four simulation counters; CPI is
`cycle_count / retired_count`:

- `cycle_count` — active cycles after reset
- `retired_count` — instructions that reach write-back
- `load_use_stall_count` — cycles lost to a load-use stall
- `taken_branch_count` — taken branches/jumps (each flushes one fetch)

#table(
  columns: (2.2fr, 1fr, 1fr, 1fr, 1fr),
  align: (left, center, center, center, center),
  inset: (x: 6pt, y: 3pt),
  stroke: 0.4pt + luma(200),
  [#text(weight: "bold", size: 9pt)[test]],
  [#text(weight: "bold", size: 9pt)[cycles]],
  [#text(weight: "bold", size: 9pt)[retired]],
  [#text(weight: "bold", size: 9pt)[stalls]],
  [#text(weight: "bold", size: 9pt)[CPI]],
  [hazard / forwarding], [49], [43], [1], [1.14],
  [branch flush / target], [29], [22], [0], [1.32],
  [bubble sort (8 words)], [528], [436], [28], [1.21],
  [fibonacci (0..9)], [134], [118], [0], [1.14],
)

- Straight-line code runs at CPI ≈ 1.14; fibonacci is the same (134 / 118).
- Bubble sort costs 1.21: 28 load-use stalls and 60 taken-branch flushes over
  436 instructions.
- The branch test isolates the flush cost — two taken branches give 1.32.
- `jal` / `isa_ext` end in an infinite loop, so their cycle count keeps growing
  after the program finishes — their CPI is not a clean efficiency figure.
- On a real workload the pong program runs ~41k cycles per 60 Hz frame.

== Bonus: a playable demo

- Verilator + raylib frontend: `pong.c` is compiled for MIPS-I with clang's
  integrated backend and loaded at the reset vector.
- Memory map: `0x00000000` RAM · `0x00010000` 64 × 32 framebuffer ·
  `0x00020000` input · `0x00020004` cycle counter · `0x00020008` frame-done.
- Runs one game frame per rendered 60 Hz frame (~41k cycles/frame); verified
  headless over 250 frames (bounces, paddle clamp, AI tracking, serves).

#figure(
  image("img/pong.png"),
  caption: [Our CPU running pong throgh Verilator]
)

#focus-slide([Thank You])
