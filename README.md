# RV8 Project: Minimal 8-bit RISC-V Style CPU Family

Build real computers from 74HC chips on breadboards. Run BASIC. Play games.

---

## CPU Variants

| | RV8-S | RV8-W | RV8 |
|--|:---:|:---:|:---:|
| **Logic chips** | **20** | 25 | 27 |
| **Total packages** | 22 | 27 | 29 |
| **MIPS** | 1.0 @10MHz | 2.5 @5MHz | 2.17 @10MHz |
| **ALU** | 1-bit serial | 8-bit parallel | 8-bit parallel |
| **Control** | Flash microcode | No microcode | Flash microcode |
| **ISA** | RISC-V reg-reg | RISC-V accumulator | RISC-V reg-reg |
| **Registers** | 8 (shift reg) | 8 (a0=accum) | 8 (all equal) |
| **Best for** | Fewest chips | **Speed + simplicity** | Flexibility |
| **BASIC** | ✅ | ✅ | ✅ |
| **Games** | ⚠️ simple | ✅ | ✅ |

---

## RV8 ISA (register-register, 35 instructions)

```asm
# ALU (any register to any register)
ADD  rd, rd, rs       SUB  rd, rd, rs       AND  rd, rd, rs
OR   rd, rd, rs       XOR  rd, rd, rs       SLT  rd, rd, rs
SLL  rd               SRL  rd

# Immediate
LI   rd, imm          ADDI rd, imm          SUBI rd, imm
ANDI rd, imm          ORI  rd, imm          XORI rd, imm
SLTI rd, imm          LUI  rd, imm

# Memory (RISC-V style)
LB   rd, off(rs)      SB   rd, off(rs)
PUSH rd               POP  rd

# Branch (compare two registers)
BEQ  rs1, rs2, off    BNE  rs1, rs2, off
BLT  rs1, rs2, off    BGE  rs1, rs2, off

# Jump
JAL  rd, off          JALR rd, rs           J off

# System
NOP   HLT   ECALL
```

---

## RV8-W ISA (accumulator, 25 instructions)

```asm
# ALU (a0 = a0 op source)
ADD  a0, a0, rs       SUB  a0, a0, rs       AND  a0, a0, rs
OR   a0, a0, rs       XOR  a0, a0, rs
SLL  a0, a0, 1        SRL  a0, a0, 1

# Immediate
LI   a0, imm          ADDI a0, a0, imm      SUBI a0, a0, imm
ANDI a0, a0, imm      ORI  a0, a0, imm      XORI a0, a0, imm

# Move
MV   a0, rs           MV   rd, a0

# Memory
LB   a0, off(rs)      SB   a0, off(rs)

# Branch (compare a0 with zero)
BEQ  a0, zero, off    BNE  a0, zero, off
BLT  a0, zero, off    BGE  a0, zero, off

# Jump
JAL  ra, off          JALR zero, ra         J off

# System
NOP   ECALL
```

---

## RV8-Bus (40-pin, shared by all variants)

```
Pin  Signal     Pin  Signal
───  ────────   ───  ────────
 1   A0          2   A1
 3   A2          4   A3
 5   A4          6   A5
 7   A6          8   A7
 9   A8         10   A9
11   A10        12   A11
13   A12        14   A13
15   A14        16   A15
17   D0         18   D1
19   D2         20   D3
21   D4         22   D5
23   D6         24   D7
25   /RD        26   /WR
27   CLK        28   /RST
29   /NMI       30   /IRQ
31   HALT       32   SYNC
33   (reserved) 34   (reserved)
35   (reserved) 36   (reserved)
37   (reserved) 38   (reserved)
39   VCC        40   GND
```

**SYNC** = instruction boundary pulse. Trainer board uses it for single-step.
All three CPU variants output identical bus signals. Same Programmer + Trainer boards work with any CPU.

---

## Project Structure

```
RV8/
├── RV8/            ← 27 chips, RISC-V reg-reg, Flash microcode
├── RV8W/           ← 25 chips, RISC-V accumulator, no microcode, 2.5 MIPS
├── RV8S/           ← 20 chips, serial ALU, same ISA as RV8, 1 MIPS
├── Programmer/     ← ESP32 board (flash ROM + terminal)
├── Old_Design/     ← Archived (RV8-G, RV8 original, RV801, RV808)
├── Reference/      ← Gigatron, SAP-1, Nand2Tetris
└── README.md
```

---

## Registers (all variants)

| Reg | ABI Name | Purpose |
|:---:|:--------:|---------|
| r0 | zero | Hardwired zero |
| r1 | a0 | Accumulator / return value |
| r2 | a1 | Argument |
| r3 | t0 | Temporary |
| r4 | t1 | Temporary |
| r5 | s0 | Saved |
| r6 | s1 | Saved / page |
| r7 | ra/sp | Return address / stack pointer |

---

## Quick Start

```bash
# Simulate RV8
cd RV8 && iverilog -o tb rv8_cpu.v tb/tb_rv8_cpu.v && vvp tb

# Flash a program
python3 Programmer/tools/rv8flash.py /dev/ttyUSB0 program.bin

# Terminal
python3 Programmer/tools/rv8term.py /dev/ttyUSB0
```

---

## Status

| Item | RV8 | RV8-W | RV8-S |
|------|:---:|:-----:|:-----:|
| Design doc | ✅ | ✅ | ✅ |
| ISA defined | ✅ | ✅ | ✅ (=RV8) |
| Verilog | ✅ (19/21) | ⬜ | ⬜ |
| WiringGuide | ✅ (verified) | ⬜ | ✅ (20 chips, issues noted) |
| Instruction trace | ✅ | ⬜ | ⬜ |
| Assembler | ⬜ | ⬜ | ⬜ |
| Programmer board | ✅ | ✅ | ✅ |
| Bus compatible | ✅ | ✅ | ✅ |
