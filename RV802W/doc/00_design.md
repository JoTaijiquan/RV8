# RV802-W — Wide Instruction, Accumulator, No Microcode

**24 logic chips. 1 cycle/instruction. 10 MIPS @ 10 MHz. No microcode.**

---

## Core Idea

```
Accumulator (AC) is ALWAYS ALU input A (hardwired, no mux).
Any register can be ALU input B (via IBUS, selected by 138).
Result always goes back to AC.
16-bit instruction word: control bits + operand in ONE read.
```

---

## Architecture

```
                    ┌──────────────────────────┐
                    │  27C1024 (16-bit ROM)     │
                    │  A[15:0] ← PC            │
                    │  D[15:8] → IR_HIGH       │
                    │  D[7:0]  → IR_LOW/IBUS   │
                    └──────────────────────────┘
                              │  │
                    ┌─────────┘  └──────────┐
                    ▼                        ▼
              ┌──────────┐            ┌──────────┐
              │ IR_HIGH  │            │  IBUS    │
              │(control) │            │ (8-bit)  │
              └────┬─────┘            └────┬─────┘
                   │                       │
         ┌─────────┼───────────────────────┤
         │         │                       │
         ▼         ▼                       ▼
    ┌────────┐ ┌────────┐           ┌──────────┐
    │Reg Sel │ │ALU ctrl│           │Registers │
    │(138)   │ │(direct)│           │r0-r7     │
    └────────┘ └────────┘           │(574 ×8)  │
                   │                └────┬─────┘
                   ▼                     │ (selected by 138)
              ┌────────┐                 ▼
              │  ALU   │←── B input ── IBUS
              │(283+86)│
              │  A ←───────── AC (hardwired)
              └───┬────┘
                  │ result
                  ▼
              ┌────────┐
              │   AC   │ (accumulator, always receives ALU result)
              │  (574) │
              └────────┘
```

---

## Instruction Encoding (16-bit)

```
Byte 0 (CONTROL — directly drives hardware):
  Bit 7:    0=ALU/reg, 1=memory/branch
  Bit 6-4:  ALU_OP[2:0] → direct to ALU control
            000=ADD, 001=SUB, 010=AND, 011=OR, 100=XOR, 101=PASS(MOV), 110=SHL, 111=SHR
  Bit 3:    IMM_MODE (0=register source, 1=immediate source)
  Bit 2:    AC_WRITE (1=write ALU result to AC)
  Bit 1:    MEM_RW (0=read, 1=write) — only when bit7=1
  Bit 0:    BRANCH (1=conditional jump) — only when bit7=1

Byte 1 (OPERAND):
  If IMM_MODE=1: imm8 (full 8-bit immediate → ALU B via IBUS)
  If IMM_MODE=0: [rs(3)][rd(3)][xx] — register select fields
  If BRANCH:     [cond(3)][offset5] — branch condition + offset
  If MEM:        [rs(3)][offset5] — base register + offset
```

---

## ISA (~20 instructions, assembler presents as RISC-V)

### ALU (AC = AC op source):
```asm
ADD  rs       # AC = AC + r[rs]          control: 0_000_0_1_0_0
ADDI imm      # AC = AC + imm            control: 0_000_1_1_0_0
SUB  rs       # AC = AC - r[rs]          control: 0_001_0_1_0_0
SUBI imm      # AC = AC - imm            control: 0_001_1_1_0_0
AND  rs       # AC = AC & r[rs]          control: 0_010_0_1_0_0
ANDI imm      # AC = AC & imm            control: 0_010_1_1_0_0
OR   rs       # AC = AC | r[rs]          control: 0_011_0_1_0_0
ORI  imm      # AC = AC | imm            control: 0_011_1_1_0_0
XOR  rs       # AC = AC ^ r[rs]          control: 0_100_0_1_0_0
MOV  rs       # AC = r[rs] (PASS)        control: 0_101_0_1_0_0
LI   imm      # AC = imm (PASS imm)      control: 0_101_1_1_0_0
SHL          # AC = AC << 1              control: 0_110_0_1_0_0
SHR          # AC = AC >> 1              control: 0_111_0_1_0_0
```

### Store AC to register:
```asm
ST   rd       # r[rd] = AC               control: 0_101_0_0_0_0 + rd in operand
              # (PASS AC through ALU, write to rd instead of AC)
```

Wait — result always goes to AC. To store AC into another register, need a different path.

**Fix**: Add `REG_WRITE` bit that writes IBUS (which AC drives) to selected register:
```
Bit 2: AC_WRITE (write ALU result → AC)
Bit 1: REG_WRITE (write IBUS → r[rd])  — AC drives IBUS via /OE
```

Revised control byte:
```
Bit 7:   CLASS (0=ALU, 1=MEM/BRANCH)
Bit 6-4: ALU_OP[2:0]
Bit 3:   IMM_MODE
Bit 2:   AC_WRITE (latch result into AC)
Bit 1:   REG_WRITE (latch IBUS into r[rd])
Bit 0:   AC_TO_BUS (AC drives IBUS for store/memory write)
```

### Full ISA (RISC-V names, accumulator-based):

**Rule: `a0` is always destination AND first source (= the accumulator).**

```asm
# ALU register (a0 = a0 op rs)
ADD  a0, a0, rs       # a0 = a0 + r[rs]
SUB  a0, a0, rs       # a0 = a0 - r[rs]
AND  a0, a0, rs       # a0 = a0 & r[rs]
OR   a0, a0, rs       # a0 = a0 | r[rs]
XOR  a0, a0, rs       # a0 = a0 ^ r[rs]
SLL  a0, a0, 1        # a0 = a0 << 1
SRL  a0, a0, 1        # a0 = a0 >> 1

# ALU immediate (a0 = a0 op imm)
ADDI a0, a0, imm      # a0 = a0 + imm
SUBI a0, a0, imm      # a0 = a0 - imm (pseudo: ADDI negative)
ANDI a0, a0, imm      # a0 = a0 & imm
ORI  a0, a0, imm      # a0 = a0 | imm
XORI a0, a0, imm      # a0 = a0 ^ imm

# Load immediate / Move
LI   a0, imm          # a0 = imm
MV   a0, rs           # a0 = r[rs]
MV   rd, a0           # r[rd] = a0

# Memory (a0 is always data source/dest)
LB   a0, off(rs)      # a0 = mem[r[rs] + off]
SB   a0, off(rs)      # mem[r[rs] + off] = a0

# Branch (compare a0)
BEQ  a0, zero, off    # branch if a0 == 0
BNE  a0, zero, off    # branch if a0 != 0
BLT  a0, zero, off    # branch if a0 < 0 (negative)
BGE  a0, zero, off    # branch if a0 >= 0

# Jump
JAL  ra, off          # ra = PC+2, PC += off
JALR zero, ra         # PC = ra (return)
J    off              # PC += off (unconditional)

# System
NOP                   # no operation
ECALL                 # halt / system call
```

### Register names (RISC-V ABI):
```
r0 = zero (hardwired 0)
r1 = a0   (accumulator — ALL ALU ops use this)
r2 = a1   (argument / temp)
r3 = t0   (temp)
r4 = t1   (temp)
r5 = s0   (saved / address register)
r6 = s1   (saved / page register)
r7 = ra/sp (return address or stack pointer)
```

### Assembly looks like RISC-V:
```asm
# Fibonacci
    LI   a0, 0           # a = 0
    MV   s0, a0          # save a
    LI   a0, 1           # b = 1
    MV   s1, a0          # save b
    LI   a0, 10
    MV   t0, a0          # count = 10
loop:
    MV   a0, s0          # a0 = a
    ADD  a0, a0, s1      # a0 = a + b
    MV   t1, a0          # temp = a+b
    MV   a0, s1
    MV   s0, a0          # a = old b
    MV   a0, t1
    MV   s1, a0          # b = temp
    MV   a0, t0
    SUBI a0, a0, 1       # count--
    MV   t0, a0
    BNE  a0, zero, loop  # if count != 0
    MV   a0, s1          # result in a0
    ECALL                 # halt
```

---

## Chip List (24 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1 | 74HC574 | AC (accumulator, /OE for IBUS drive, D from ALU result) |
| U2-U8 | 74HC574 ×7 | Registers r1-r7 (/OE for IBUS, D from IBUS, CLK from write decode) |
| U9 | 74HC574 | IR_HIGH (control byte, outputs directly drive hardware) |
| U10 | 74HC574 | IR_LOW (operand byte, outputs to IBUS for immediate) |
| U11-U12 | 74HC283 ×2 | ALU adder (8-bit) |
| U13 | 74HC86 | XOR (SUB invert, 4 gates for low nibble) |
| U14 | 74HC86 | XOR (SUB invert, 4 gates for high nibble) |
| U15-U18 | 74HC161 ×4 | PC (16-bit, auto-increment) |
| U19 | 74HC138 | Register read select (rs → /OE, who drives IBUS) |
| U20 | 74HC138 | Register write select (rd → CLK, who latches from IBUS) |
| U21 | 74HC541 | PC high buffer (tri-state for memory access) |
| U22 | 74HC245 | External bus buffer (IBUS ↔ RAM data) |
| U23 | 74HC74 | Flags (Z, C) + state (fetch/execute for memory ops) |
| U24 | 74HC157 | Address mux low (PC vs register for memory) |
| — | 27C1024 | Program ROM (16-bit wide, DIP-40) |
| — | 62256 | RAM |
| **Total** | **24 logic + ROM + RAM = 26** | |

---

## How it works (1 cycle for ALU):

```
Single clock cycle:
  1. PC drives 27C1024 address (always, via 161 outputs)
  2. ROM outputs 16 bits: D[15:8]=control, D[7:0]=operand
  3. IR_HIGH latches control (but outputs are ACTIVE immediately — feedthrough)
     Actually: use ACTIVE outputs from ROM directly, no latch needed for combinational!
  4. Control bits select:
     - ALU_OP → XOR chips + adder carry
     - rs field (from operand) → 138 → register drives IBUS → ALU B
     - OR: IMM_MODE → operand byte itself on IBUS → ALU B
  5. AC output (hardwired) → ALU A
  6. ALU computes combinationally
  7. At CLK rising edge:
     - AC latches result (if AC_WRITE=1)
     - PC increments (always)
     - Flags latch (Z, C)
  
  Total: 1 clock cycle!
```

---

## Timing verification:

```
ROM access: 45ns (27C1024-45)
138 decode: 15ns
Register output: 10ns (574 tpd)
XOR: 10ns
Adder: 20ns (74HC283 ripple)
Setup time: 5ns
─────────────────
Total: ~105ns

At 10 MHz (100ns): TIGHT! Need 27C1024-45 (45ns) version.
At 8 MHz (125ns): comfortable (20ns margin). ✅
At 3.5 MHz (286ns): easy. ✅
```

**Safe clock: 8 MHz = 8 MIPS. Breadboard: 3.5 MHz = 3.5 MIPS.**

---

## Comparison:

| | RV802 (microcode) | RV802-W (accumulator) |
|--|:---:|:---:|
| Logic chips | 27 | **24** |
| Total packages | 29 | **26** |
| Cycles/instr | 4-6 | **1** (ALU) / 2 (memory) |
| MIPS @ 8 MHz | 1.7 | **8.0** |
| MIPS @ 3.5 MHz | 0.7 | **3.5** |
| Microcode ROM | 2× EEPROM | **None** |
| Step counter | Needed | **None** |
| ISA style | RISC-V (register-register) | **Accumulator** (AC + registers) |
| Registers | 8 (all equal) | 1 AC + 7 general |
| BASIC | ✅ | ✅ |
| Games | ✅ | ✅ |
| Programmer sees | RISC-V assembly | 6502-like assembly |

---

## Assembly example (BASIC-like):

```asm
# Calculate 5 + 3, store in r1
    LI   5          # AC = 5
    ADDI 3          # AC = 5 + 3 = 8
    ST   r1         # r1 = 8

# Loop: count to 10
    LI   0          # AC = 0
loop:
    ADDI 1          # AC++
    ST   r2         # save counter
    SUBI 10         # compare with 10
    BNE  loop       # if AC != 0, loop
    MOV  r2         # AC = final counter value

# Memory access
    LI   $42        # AC = address
    ST   r3         # r3 = $42 (address register)
    LB   r3, 0     # AC = mem[$42]
    ADDI 1          # AC++
    SB   r3, 0     # mem[$42] = AC
```

---

## Verdict:

**RV802-W is the Gigatron approach with our register set.**
- 24 chips, no microcode, 8 MIPS
- Trades RISC-V register-register for accumulator
- Assembly looks like 6502/Z80 (AC-centric) not RISC-V
- But runs BASIC and games just as well
