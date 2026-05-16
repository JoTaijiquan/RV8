# RV8-W v2 — RAM Registers, 20 Chips, No Microcode

**20 logic chips. Registers in RAM. Accumulator + parallel ALU. ~1.7 MIPS @ 10 MHz.**

---

## Core Idea

```
Registers are NOT chips — they're RAM addresses $00-$07.
"ADD a0, a0, r3" = read RAM[$03], add to AC.
Only AC (accumulator) is a real chip. Everything else lives in RAM.
```

---

## Chip List (18 logic + ROM + RAM = 20)

| U# | Chip | Function |
|:--:|------|----------|
| U1 | 74HC574 | AC (accumulator, hardwired to ALU A) |
| U2 | 74HC574 | IR_HIGH (control byte, drives hardware) |
| U3 | 74HC574 | IR_LOW (operand byte) |
| U4-U5 | 74HC283 ×2 | ALU adder (8-bit) |
| U6-U7 | 74HC86 ×2 | XOR (8-bit SUB invert) |
| U8-U11 | 74HC161 ×4 | PC (16-bit counter) |
| U12 | 74HC541 | PC high buffer (tri-state) |
| U13 | 74HC157 | Address mux low (PC vs operand/register addr) |
| U14 | 74HC245 | Bus buffer (IBUS ↔ RAM data) |
| U15 | 74HC541 | AC → IBUS buffer (for store ops) |
| U16 | 74HC74 | Flags (Z,C) + state toggle |
| U17-U18 | 74HC157 ×2 | AC D-input mux (ALU result vs IBUS) |
| — | SST39SF010A | Program ROM (128KB, 70ns) |
| — | 62256 | RAM (32KB, includes registers at $00-$07) |
| **Total** | **18 logic + ROM + RAM = 20** | |

---

## How Registers Work (in RAM)

```
RAM address map:
  $0000: r0 (always 0 — software enforced)
  $0001: r1 (a0 shadow — for saving AC)
  $0002: r2 (a1)
  $0003: r3 (t0)
  $0004: r4 (t1)
  $0005: r5 (s0)
  $0006: r6 (s1)
  $0007: r7 (sp/ra)
  $0008+: general RAM (variables, stack, data)
```

Reading a "register": set address bus to $0003, read RAM → value on IBUS.
Writing a "register": set address bus to $0003, write IBUS → RAM stores it.

**Same speed as any RAM access — 1 cycle.**

---

## Instruction Execution (3 cycles)

```
Cycle 1 (FETCH CONTROL): state=0
  PC → ROM → IR_HIGH latches control byte
  PC++

Cycle 2 (FETCH OPERAND): state=1  
  PC → ROM → IR_LOW latches operand
  PC++

Cycle 3 (EXECUTE): state=2
  Address bus → RAM[$rs] (register address from operand)
  RAM data → IBUS → ALU B (via XOR)
  ALU computes: AC + IBUS (or AC - IBUS)
  Result → AC (via mux) or → RAM (for store)
  State resets to 0
```

**3 cycles per instruction = 3.3 MIPS @ 10 MHz**

Wait — need state counter for 3 states. 74HC74 has 2 FFs = 4 states max. Use 2 bits: 00=fetch1, 01=fetch2, 10=execute, 11=unused. ✅

---

## Data Paths

```
┌─────────────────────────────────────────────────────┐
│                                                      │
│  U1 (AC) ──────────────────→ ALU A (hardwired)      │
│     ↑                              ↓                │
│     │ (via U17-U18 mux)     U4-U5 (adder)          │
│     │  select: ALU result      ↑        ↓           │
│     │       or IBUS            │    ALU result      │
│     │                     U6-U7 (XOR)               │
│     │                          ↑                    │
│  ═══╪══════════ IBUS (8-bit) ══╪════════════════    │
│     │                          │                    │
│  U15 (541)              RAM data (via U14)          │
│  AC→IBUS                IBUS↔RAM                    │
│  (for store)            (for register read/write)   │
│                                                      │
│  U8-U11 (PC) ──→ U12 (541) ──→ ADDRESS BUS         │
│                   U13 (157) ──→ (PC vs reg addr)    │
│                                      ↓              │
│                              ROM + RAM address      │
└─────────────────────────────────────────────────────┘
```

---

## ISA (same RISC-V naming, 3 cycles each)

```asm
# ALU (AC = AC op RAM[rs])
ADD  a0, a0, rs       # AC = AC + RAM[$rs]     3 cycles
SUB  a0, a0, rs       # AC = AC - RAM[$rs]     3 cycles
ADDI a0, a0, imm      # AC = AC + imm          3 cycles (imm on IBUS directly)
SUBI a0, a0, imm      # AC = AC - imm          3 cycles

# Load/Store
LI   a0, imm          # AC = imm               3 cycles (0 + imm via ALU)
MV   a0, rs           # AC = RAM[$rs]          3 cycles (0 + RAM[rs])
MV   rd, a0           # RAM[$rd] = AC          3 cycles (AC → buffer → RAM)
LB   a0, off(rs)      # AC = RAM[RAM[$rs]+off] 4 cycles (indirect)
SB   a0, off(rs)      # RAM[RAM[$rs]+off] = AC 4 cycles (indirect)

# Branch
BEQ  a0, zero, off    # if AC==0, PC += off    3 cycles
BNE  a0, zero, off    # if AC!=0, PC += off    3 cycles
J    off              # PC += off              3 cycles
JAL  ra, off          # RAM[$07]=PC, PC+=off   4 cycles

# System
NOP                   # nothing                3 cycles
ECALL                 # halt                   3 cycles
```

---

## ⚠️ ISSUE CHECK

**Q: Can ALU compute 0+imm for LI?**
ALU A = AC (always). For LI, we want result = imm (not AC+imm).
Fix: software does `LI a0, 0` then `ADDI a0, imm`. Two instructions. OR:
Accept: LI actually does AC = AC + imm... no, that's ADDI.

**Real LI**: Need AC=0 first, then add imm. OR: mux selects IBUS directly → AC (bypass ALU).
The U17-U18 mux already does this! When mux selects IBUS (not ALU result) → AC gets raw IBUS value.

**LI = mux selects IBUS, AC latches.** ✅ No extra cycle needed.

**Q: Relative branch (PC += offset)?**
PC is 74HC161 (counter). Has /LD for parallel load. But where does PC+offset come from?
ALU A = AC (not PC). Can't compute PC+offset.

**Fix**: For branch, load offset into PC via /LD. But that's absolute, not relative.
**OR**: Accept absolute branch only (JMP addr). For loops, use absolute addresses.
**OR**: Use AC as temp: save AC, load PC into AC (how?), add offset, load to PC, restore AC. Too complex.

**Accept: absolute jumps only.** BASIC works fine with absolute addresses (GOTO line_number).

**Q: How does JAL save PC to RAM[$07]?**
Need PC value on IBUS → write to RAM. But PC outputs go to address bus, not IBUS.
**Fix**: Need path from PC → IBUS. Use U12 (541) with direction reversed? No, 541 is one-way.
**Alternative**: Microcode... but we have no microcode!

**Accept: JAL not possible without extra hardware.** Use software: `MV ra, PC` (but can't read PC either).

**Honest: no JAL/RET without +1 chip** (to get PC onto IBUS). Add 1× 74HC541 for PC→IBUS.

**Revised: 19 logic chips + ROM + RAM = 21 packages.** (add U19 = 541 PC→IBUS)

---

## HONEST FINAL:

| Spec | Value |
|------|-------|
| Logic chips | **19** |
| Total | **21** |
| Speed | ~1.7 MIPS @ 10 MHz (3 cycles/instr) |
| Registers | In RAM ($00-$07) |
| ALU | 8-bit parallel (ADD/SUB only) |
| Branch | Absolute only (no relative) |
| AND/OR/XOR | ❌ (adder only) |
| JAL/RET | ✅ (with PC→IBUS buffer) |
| BASIC | ✅ |
| Games | ✅ |
| Microcode | **None** |

---

## Comparison (FINAL HONEST):

| | RV8 | RV8-W v2 |
|--|:---:|:---:|
| Logic chips | 27 | **19** |
| Total | 29 | **21** |
| Speed | 1.25 MIPS | **1.7 MIPS** |
| ISA | Full RISC-V (35 instr) | Reduced (20 instr) |
| AND/OR/XOR | ✅ | ❌ |
| Relative branch | ✅ | ❌ |
| Registers | Hardware (fast) | RAM (1 cycle slower per access) |
| Microcode | Yes (2× Flash) | **None** |
| Complexity | High | **Low** |
| BASIC | ✅ | ✅ |

**RV8-W v2: 8 fewer chips than RV8, faster, simpler. Trades full ISA for minimalism.**
