# RV8-GR — Reduced ISA, No Microcode, RAM Registers

**21 logic chips. No microcode. Plays games. Mostly compatible with RV8.**

---

## Specs

| Spec | Value |
|------|-------|
| Logic chips | 21 |
| Total | 23 |
| ISA | 21 instructions (~80% RV8 compatible) |
| Speed | 1.7 MIPS @ 10 MHz |
| Registers | 8 in RAM ($00-$07) |
| Control | 8-bit instruction byte + ~3 gates (no microcode, no Flash lookup) |
| Compatibility | ~80% of RV8 programs (missing AND/OR/SRL only) |

---

## Instruction Encoding (2 bytes: control + operand)

### Byte 0 — Control (encodes instruction type, 8 bits):
```
Bit 7: ALU_SUB      — 0=ADD, 1=SUB
Bit 6: XOR_MODE     — 1=XOR result to AC (bypass adder)
Bit 5: MUX_SEL      — 0=ALU result→AC, 1=IBUS→AC (for LI/LB)
Bit 4: AC_WR        — 1=write to AC this cycle
Bit 3: SOURCE_TYPE  — 0=immediate (operand=value), 1=register (operand=RAM addr)
Bit 2: STORE        — 1=write AC to RAM[operand]
Bit 1: BRANCH       — 1=conditional jump (check Z flag)
Bit 0: JUMP         — 1=unconditional PC load
```

### Byte 1 — Operand (data or address, 8 bits):
```
If SOURCE_TYPE=0: immediate value (0-255)
If SOURCE_TYPE=1: register address ($00-$07)
If STORE=1:       destination RAM address
If BRANCH/JUMP:   target address
```

### Derived signals (2-3 gates from spare logic, no extra chips):
```
ADDR_MODE = SOURCE_TYPE OR STORE
BUF_OE    = SOURCE_TYPE OR STORE
BUF_DIR   = STORE
AC_TO_BUS = STORE
```

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

**Revised: RV8-GR gets XOR at no extra cost.** ISA = 21 instructions.

---

## Compatibility with RV8

| RV8 instruction | RV8-GR | Notes |
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

## Programs that run unchanged on RV8-GR:
- Any program that doesn't use AND/OR/SRL/relative-branch
- Most arithmetic (ADD, SUB, shifts via ADD)
- All memory access (LB, SB, PUSH, POP)
- All jumps and calls (JAL, RET)
- Simple games (no bit manipulation)
- BASIC (if interpreter avoids AND/OR — use SUB+branch instead)

---

## Chip List (19 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1 | 74HC574 | AC (accumulator, hardwired to ALU A) |
| U2 | 74HC574 | IR_HIGH (control byte, drives hardware) |
| U3-U4 | 74HC283 ×2 | ALU adder (8-bit) |
| U5-U6 | 74HC86 ×2 | XOR (SUB invert + XOR instruction) |
| U7 | 74HC157 | Address mux A[7:4] |
| U8 | 74HC574 | IR_LOW (operand byte) |
| U9 | 74HC541 | AC → IBUS buffer (for store/move) |
| U10 | 74HC245 | Bus buffer (IBUS ↔ RAM) |
| U11-U12 | 74HC157 ×2 | AC D-input mux (adder vs IBUS vs XOR) |
| U13 | 74HC157 | Address mux A[3:0] (PC vs operand) |
| U14 | 74HC74 | Flags (Z) + state toggle |
| U15-U18 | 74HC161 ×4 | PC (16-bit counter) |
| U19 | 74HC541 | PC → IBUS buffer (for JAL) |
| — | SST39SF010A | Program ROM (128KB, 70ns) |
| — | 62256 | RAM (32KB, includes registers $00-$07) |

**No microcode. No Flash lookup. Control byte bits + 3 derived gates = all signals.**

---

## Status

- ✅ Design document (00_design.md)
- ✅ ISA reference (01_isa_reference.md)
- ✅ Instruction trace (02_instruction_trace.md) — verified 21 chips
- ✅ WiringGuide (03_wiring_guide.md) — bus-centric, no conflicts
- ✅ Understand by Module (04_understand_by_module.md)
- ✅ Verilog model (rv8gr_cpu.v) — **11/11 tests pass**
- ⬜ Assembler
- ⬜ Physical build

## Files

```
RV8GR/
├── README.md
├── rv8gr_cpu.v           ← Verilog (11/11 pass)
├── tb/tb_rv8gr_cpu.v     ← testbench
└── doc/
    ├── 00_design.md
    ├── 01_isa_reference.md
    ├── 02_instruction_trace.md
    ├── 03_wiring_guide.md
    └── 04_understand_by_module.md
```
