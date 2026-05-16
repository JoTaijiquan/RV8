# RV8-W — Wide Instruction, Accumulator, No Microcode

**24 logic chips. 2 cycles/instruction. 5 MIPS @ 10 MHz. No microcode. RISC-V naming.**

---

## Specs

| Parameter | Value |
|-----------|-------|
| Logic chips | 24 |
| Total packages | 26 (+ ROM + RAM) |
| Gates | ~640 |
| ISA | ~25 instructions, accumulator (a0-centric), RISC-V naming |
| Instruction | 16-bit (2 bytes: control + operand) |
| Fetch | 2 cycles (read control byte, read operand + execute) |
| Control | **None** — control byte bits directly drive hardware |
| Microcode | **None** |
| Step counter | **None** |
| Cycles/instruction | 2 (ALU/branch) / 3 (memory) |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| MIPS | 1.75 @ 3.5 MHz / **5.0 @ 10 MHz** |
| Registers | 8 (a0=accumulator, r0=zero, ra=return, sp=stack) |
| Program ROM | SST39SF010A (128KB, 8-bit, 70ns, PDIP-32, Flash) |
| RAM | 62256 (32KB) |
| Programmer | ESP32 board (flash via 40-pin bus) ✅ |

---

## Chip List (24 logic)

| U# | Chip | Function | Gates |
|:--:|------|----------|:-----:|
| U1 | 74HC574 | a0 (accumulator, hardwired to ALU A) | 30 |
| U2-U8 | 74HC574 ×7 | r1-r7 (general registers) | 210 |
| U9 | 74HC574 | IR_HIGH (control byte, outputs drive hardware) | 30 |
| U10 | 74HC574 | IR_LOW (operand, feeds IBUS for immediate/ALU B) | 30 |
| U11-U12 | 74HC283 ×2 | ALU adder (8-bit) | 100 |
| U13-U14 | 74HC86 ×2 | XOR (8-bit SUB invert) | 60 |
| U15-U18 | 74HC161 ×4 | PC (16-bit, auto-increment) | 100 |
| U19 | 74HC138 | Register read select (rs → /OE) | 30 |
| U20 | 74HC138 | Register write select (rd → CLK) | 30 |
| U21 | 74HC541 | PC high buffer (tri-state for data access) | 40 |
| U22 | 74HC245 | External bus buffer (IBUS ↔ RAM) | 40 |
| U23 | 74HC74 | Flags (Z,C) + state toggle (fetch/execute) | 25 |
| U24 | 74HC157 | Address mux low (PC vs register) | 35 |
| — | SST39SF010A | Program ROM (128KB, 8-bit, 70ns Flash) | — |
| — | 62256 | Data RAM (32KB) | — |
| **Total** | **24 logic** | | **~640** |

---

## Gate Count by Function

| Function | Chips | Gates | % |
|----------|:-----:|:-----:|:-:|
| Registers (a0 + r1-r7) | 8 | 240 | 37% |
| ALU (adder + XOR) | 4 | 160 | 25% |
| PC (16-bit counter) | 4 | 100 | 16% |
| IR (control + operand) | 2 | 60 | 9% |
| Decode (read + write) | 2 | 60 | 9% |
| Address/bus (541+245+157) | 3 | 115 | — |
| Flags + state | 1 | 25 | 4% |
| **Total** | **24** | **~640** | |

---

## ISA (~25 instructions, RISC-V naming)

**Rule: `a0` is always destination AND first source.**

```asm
# ALU register
ADD  a0, a0, rs       # a0 = a0 + r[rs]
SUB  a0, a0, rs       # a0 = a0 - r[rs]
AND  a0, a0, rs       # a0 = a0 & r[rs]
OR   a0, a0, rs       # a0 = a0 | r[rs]
XOR  a0, a0, rs       # a0 = a0 ^ r[rs]
SLL  a0, a0, 1        # a0 = a0 << 1
SRL  a0, a0, 1        # a0 = a0 >> 1

# ALU immediate
ADDI a0, a0, imm      # a0 = a0 + imm
SUBI a0, a0, imm      # a0 = a0 - imm
ANDI a0, a0, imm      # a0 = a0 & imm
ORI  a0, a0, imm      # a0 = a0 | imm
XORI a0, a0, imm      # a0 = a0 ^ imm

# Load/Move
LI   a0, imm          # a0 = imm
MV   a0, rs           # a0 = r[rs]
MV   rd, a0           # r[rd] = a0

# Memory
LB   a0, off(rs)      # a0 = mem[r[rs] + off]
SB   a0, off(rs)      # mem[r[rs] + off] = a0

# Branch (compare a0 with zero)
BEQ  a0, zero, off    # branch if a0 == 0
BNE  a0, zero, off    # branch if a0 != 0
BLT  a0, zero, off    # branch if a0 < 0 (signed)
BGE  a0, zero, off    # branch if a0 >= 0

# Jump
JAL  ra, off          # ra = PC, jump PC+off
JALR zero, ra         # return (PC = ra)
J    off              # unconditional jump

# System
NOP                   # no operation
ECALL                 # halt / system call
```

---

## How It Works (2-cycle)

```
Cycle 1 (FETCH CONTROL):
  State=0
  PC → ROM address → ROM outputs control byte
  IR_HIGH latches control byte
  PC increments

Cycle 2 (FETCH OPERAND + EXECUTE):
  State=1
  PC → ROM address → ROM outputs operand byte
  Operand available on IBUS (for immediate) OR register selected (for reg ops)
  IR_HIGH outputs ACTIVE → drive ALU op, register select, etc.
  ALU computes combinationally (a0 + IBUS → result)
  At CLK edge: a0 latches result, flags update, PC increments
  State resets to 0
```

---

## Comparison (all designs)

| | RV8 | **RV8-W** | RV8-G |
|--|:---:|:---:|:---:|
| Logic chips | 27 | **24** | 26 |
| Total | 29 | **26** | 28 |
| Gates | ~765 | **~640** | ~820 |
| MIPS @ 10 MHz | 2.17 | **5.0** | 2.5 |
| Microcode | 2× Flash | **None** | None (gates) |
| ISA style | RISC-V reg-reg | **RISC-V accumulator** | Accumulator |
| Cycles/instr | 4-6 | **2** | 4 |
| Program ROM | AT28C256 | **SST39SF010A** | AT28C256 |
| Easy to program | ✅ | **✅ (Flash)** | ✅ |
| BASIC | ✅ | **✅** | ✅ |
| Games | ✅ | **✅** | ✅ |

---

## Status

- ✅ Design document
- ✅ ISA defined (RISC-V naming)
- ⬜ Instruction trace (verify wiring)
- ⬜ Verilog model
- ⬜ WiringGuide
- ⬜ Assembler
- ⬜ Build
