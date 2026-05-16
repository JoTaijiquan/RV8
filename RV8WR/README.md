# RV8-WR — Reduced ISA, No Microcode, RAM Registers

**19 logic chips. No microcode. Plays games. Mostly compatible with RV8.**

---

## Specs

| Spec | Value |
|------|-------|
| Logic chips | 19 |
| Total | 21 |
| ISA | 20 instructions (subset of RV8) |
| Speed | 1.7 MIPS @ 10 MHz |
| Registers | 8 in RAM ($00-$07) |
| Control | **None** — instruction bits drive hardware directly |
| Compatibility | ~70% of RV8 programs run unchanged |

---

## ISA (RISC-V naming, subset of RV8)

### ✅ Works (same encoding as RV8):

```asm
# ALU
ADD  a0, a0, rs       # AC = AC + RAM[rs]
SUB  a0, a0, rs       # AC = AC - RAM[rs]
ADDI a0, a0, imm      # AC = AC + imm
SUBI a0, a0, imm      # AC = AC - imm
SLL  a0, a0, 1        # AC = AC + AC (shift left = add to self)

# Load/Store/Move
LI   a0, imm          # AC = imm
MV   a0, rs           # AC = RAM[rs]
MV   rd, a0           # RAM[rd] = AC
LB   a0, off(rs)      # AC = mem[RAM[rs] + off]
SB   a0, off(rs)      # mem[RAM[rs] + off] = AC

# Branch (compare AC with zero)
BEQ  a0, zero, addr   # if AC==0, jump to addr (absolute)
BNE  a0, zero, addr   # if AC!=0, jump to addr (absolute)

# Jump
JAL  ra, addr         # RAM[ra]=PC, jump to addr
JALR zero, ra         # jump to RAM[ra] (return)
J    addr             # unconditional jump

# System
NOP
ECALL                 # halt
```

### ❌ Not available (need extra chips):

```asm
AND  a0, a0, rs       # ← needs 74HC08 ×2
OR   a0, a0, rs       # ← needs 74HC32 ×2
XOR  a0, a0, rs       # ← needs 74HC86 (already have for SUB... could reuse?)
ANDI/ORI/XORI         # ← same
SRL  a0, a0, 1        # ← needs dedicated shift hardware
SLT/SLTI              # ← needs flag routing
BEQ  rs1, rs2, off    # ← needs ALU A mux (relative + reg compare)
BLT/BGE               # ← same
```

### ⚠️ Available via assembler macro (slower, 3-4 instructions):

```asm
# Relative branch (assembler expands automatically):
BEQ_REL a0, zero, +10  →  BNE a0, zero, skip
                           MV  a0, PC
                           ADDI a0, 10
                           JMP a0
                       skip:

# XOR (partial — reuse SUB XOR chip if wired for it):
# Only possible if U6-U7 (86) are accessible for general XOR
# Design decision: wire XOR as general-purpose? Then XOR works! (+0 chips)
```

---

## XOR for free?

The 2× 74HC86 (U6-U7) are used for SUB (invert B). But XOR gate does: `A XOR B`.

If we route AC and IBUS through the XOR chips **without** going through the adder:
```
AC → XOR A input
IBUS → XOR B input  
XOR output → AC (bypass adder)
```

This needs a mux to select: AC.D ← adder output OR XOR output. That's the same U17-U18 mux we already have (AC D-input mux)!

**XOR is FREE if we add one mux setting!** The XOR chips are already there. Just route their output as an alternative to the adder output.

**Revised: RV8-WR gets XOR at no extra cost.** ISA = 21 instructions.

---

## Compatibility with RV8

| RV8 instruction | RV8-WR | Notes |
|-----------------|:------:|-------|
| ADD/SUB/ADDI/SUBI | ✅ | Same |
| XOR/XORI | ✅ | Free (reuse XOR chips) |
| AND/ANDI | ❌ | Need +2 chips |
| OR/ORI | ❌ | Need +2 chips |
| SLL | ✅ | ADD a0,a0 |
| SRL | ❌ | Need hardware |
| LI/MV/LB/SB | ✅ | Same |
| BEQ/BNE (absolute) | ✅ | Same (absolute only) |
| BEQ/BNE (relative) | ⚠️ | Assembler macro (4 instr) |
| JAL/JALR | ✅ | Same |
| PUSH/POP | ✅ | Via RAM[sp] |
| **Compatibility** | | **~80% of RV8 programs** |

---

## Programs that run unchanged on RV8-WR:
- Any program that doesn't use AND/OR/SRL/relative-branch
- Most arithmetic (ADD, SUB, shifts via ADD)
- All memory access (LB, SB, PUSH, POP)
- All jumps and calls (JAL, RET)
- Simple games (no bit manipulation)
- BASIC (if interpreter avoids AND/OR — use SUB+branch instead)
