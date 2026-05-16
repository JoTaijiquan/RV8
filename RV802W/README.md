# RV802-W — Wide Instruction, Accumulator, No Microcode

**24 logic chips. 1 cycle/instruction. 8 MIPS @ 8 MHz. No microcode. RISC-V naming.**

## Specs

| Parameter | Value |
|-----------|-------|
| Logic chips | 24 (+ ROM + RAM = 26 total) |
| ISA | ~25 instructions, accumulator (a0-centric) |
| Instruction width | 16-bit (control + operand in one word) |
| Control | **None** — instruction bits ARE control signals |
| Cycles/instruction | 1 (ALU) / 2 (memory) |
| MIPS | 8.0 @ 8 MHz / 3.5 @ 3.5 MHz |
| Registers | 8 (a0=accumulator, r0=zero, ra=return) |
| Program ROM | 27C1024 (16-bit wide, DIP-40) |
| RAM | 62256 (32KB) |

## ISA (RISC-V naming)

```asm
ADD  a0, a0, rs       # a0 = a0 + rs
ADDI a0, a0, imm      # a0 = a0 + imm
SUB  a0, a0, rs       # a0 = a0 - rs
AND/OR/XOR a0, a0, rs # logic ops
SLL  a0, a0, 1        # shift left
SRL  a0, a0, 1        # shift right
LI   a0, imm          # load immediate
MV   a0, rs           # move to accumulator
MV   rd, a0           # move from accumulator
LB   a0, off(rs)      # load byte
SB   a0, off(rs)      # store byte
BEQ  a0, zero, off    # branch if zero
BNE  a0, zero, off    # branch if not zero
JAL  ra, off          # jump and link
JALR zero, ra         # return
```

**Rule: `a0` is always involved.** Like RISC-V compressed but 8-bit.

## Status

- ✅ Design document
- ⬜ Verilog model
- ⬜ WiringGuide (trace verification)
- ⬜ Assembler
- ⬜ Build

## Files

```
RV802W/
└── doc/
    └── 00_design.md    ← full architecture + ISA + chip list
```
