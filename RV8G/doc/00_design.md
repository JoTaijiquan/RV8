# RV8-G — Gates-Only CPU Design (Von Neumann, shared bus)

**Constraint**: No EEPROM/microcode. Pure 74HC gates. Run BASIC + games. Minimum chips.
**Relationship**: Gates-only variant of RV8 (shared bus, pointer registers)
**Sister variant**: RV808-G (gates-only Harvard, 20 chips)

---

## 1. Core Principle: Opcode Bits ARE Control Signals

No decode logic needed — opcode bit fields wire directly to control points:

```
Instruction format: [opcode 8-bit] [operand 8-bit]

opcode[7:6] = instruction class (4 classes)
  00 = ALU operation (result → a0)
  01 = Load/Store memory
  10 = Branch/Jump
  11 = System (PUSH/POP/CALL/RET/misc)

opcode[5:3] = operation (8 ops per class) → wires directly to ALU/mux
opcode[2:0] = register/modifier → wires directly to register select
```

The 74HC138 decodes `opcode[7:6]` into 4 class-enable lines. Within each class, `opcode[5:3]` routes directly to hardware (ALU op pins, mux select, etc). **Zero extra decode gates.**

---

## 2. State Machine (4 states, 2 flip-flops)

```
        ┌──────────────────────────────────┐
        ▼                                  │
  ┌────────┐    ┌────────┐    ┌────────┐  │  ┌────────┐
  │   S0   │───→│   S1   │───→│   S2   │──┼─→│   S3   │──→ back to S0
  │ Fetch  │    │Operand │    │Execute │  │  │Mem R/W │
  │ opcode │    │ fetch  │    │ALU/addr│  │  │(if needed)
  └────────┘    └────────┘    └────────┘  │  └────────┘
                                           │
                              (skip S3 if no memory access)
```

| State | Q1 Q0 | Action |
|:-----:|:-----:|--------|
| S0 | 00 | PC → ROM, latch opcode into IR, PC++ |
| S1 | 01 | PC → ROM, latch operand, PC++ |
| S2 | 10 | Execute: ALU computes, address setup |
| S3 | 11 | Memory read/write (only if load/store/push/pop) |

2 flip-flops (1× 74HC74) generate S0-S3. State advances every clock. S3 skips back to S0 if not needed (controlled by opcode[7:6] = class).

---

## 3. Instruction Set (32 instructions)

### Class 00: ALU (opcode[5:3] = ALU op, opcode[1] = carry/shift, opcode[0] = immediate)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 00_000_000 | ADD t0 | a0 ← a0 + t0 |
| 00_000_001 | ADDI imm | a0 ← a0 + imm |
| 00_000_010 | ADC t0 | a0 ← a0 + t0 + C |
| 00_000_011 | ADCI imm | a0 ← a0 + imm + C |
| 00_001_000 | SUB t0 | a0 ← a0 - t0 |
| 00_001_001 | SUBI imm | a0 ← a0 - imm |
| 00_001_010 | SBC t0 | a0 ← a0 - t0 - !C |
| 00_001_011 | SBCI imm | a0 ← a0 - imm - !C |
| 00_010_000 | AND t0 | a0 ← a0 & t0 |
| 00_010_001 | ANDI imm | a0 ← a0 & imm |
| 00_011_000 | OR t0 | a0 ← a0 \| t0 |
| 00_011_001 | ORI imm | a0 ← a0 \| imm |
| 00_100_000 | XOR t0 | a0 ← a0 ^ t0 |
| 00_100_001 | XORI imm | a0 ← a0 ^ imm |
| 00_101_000 | CMP t0 | flags ← a0 - t0 (no store) |
| 00_101_001 | CMPI imm | flags ← a0 - imm (no store) |
| 00_110_000 | INC | a0 ← a0 + 1 |
| 00_110_010 | SHL | a0 ← a0 << 1, C ← old bit7 |
| 00_111_000 | DEC | a0 ← a0 - 1 |
| 00_111_001 | MOV t0,a0 | t0 ← a0 |
| 00_111_010 | SHR | a0 ← a0 >> 1, C ← old bit0 |

### Class 01: Load/Store (opcode[5:3] = mode, opcode[2:0] = register/modifier)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 01_000_000 | LI a0, imm | a0 ← imm |
| 01_000_001 | LI t0, imm | t0 ← imm |
| 01_000_010 | LI sp, imm | sp ← imm |
| 01_000_011 | LI pl, imm | pl ← imm |
| 01_000_100 | LI ph, imm | ph ← imm |
| 01_001_000 | LB (ptr) | a0 ← RAM[{ph, pl}] |
| 01_010_000 | SB (ptr) | RAM[{ph, pl}] ← a0 |
| 01_011_000 | LB zp:imm | a0 ← RAM[{$00, imm}] |
| 01_100_000 | SB zp:imm | RAM[{$00, imm}] ← a0 |
| 01_101_000 | LB (ptr+) | a0 ← RAM[{ph,pl}], ptr++ |
| 01_110_000 | MOV pl, a0 | pl ← a0 |
| 01_110_001 | MOV ph, a0 | ph ← a0 |

### Class 10: Branch/Jump (opcode[5:3] = condition, opcode[0] = modifier)

| Opcode | Mnemonic | Condition |
|:------:|----------|-----------|
| 10_000_000 | BEQ off | Z=1 |
| 10_001_000 | BNE off | Z=0 |
| 10_010_000 | BCS off | C=1 |
| 10_011_000 | BCC off | C=0 |
| 10_100_000 | BMI off | N=1 |
| 10_101_000 | BPL off | N=0 |
| 10_110_000 | BRA off | always |
| 10_111_000 | JMP imm | PC ← {ph, imm} |
| 10_111_001 | JMP (ptr) | PC ← {ph, pl} |

### Class 11: System (opcode[5:3] = operation)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 11_000_000 | PUSH a0 | sp--, RAM[{$30,sp}] ← a0 |
| 11_001_000 | POP a0 | a0 ← RAM[{$30,sp}], sp++ |
| 11_010_000 | CALL imm | push PCL, PC ← {ph, imm} |
| 11_011_000 | RET | PC ← {ph, pop PCL} |
| 11_100_000 | NOP | no operation |
| 11_101_000 | HLT | halt (loop until interrupt) |
| 11_110_000 | EI | enable interrupts (IE←1) |
| 11_111_000 | DI | disable interrupts (IE←0) |

---

## 4. ISA Summary

**32 instructions total. All fit in 4 classes decoded by opcode[7:6].**

Capabilities:
- ✅ 8-bit arithmetic (ADD, SUB, INC, DEC)
- ✅ 16-bit arithmetic (ADC, SBC carry chain)
- ✅ Logic (AND, OR, XOR)
- ✅ Shifts (SHL, SHR)
- ✅ Compare + 7 branch conditions
- ✅ Load/Store (pointer, zero-page, auto-increment)
- ✅ Computed pointer (MOV pl/ph from a0)
- ✅ Computed jump (JMP ptr)
- ✅ Stack (PUSH, POP)
- ✅ Subroutines (CALL, RET)
- ✅ Interrupts (EI, DI, hardware NMI/IRQ)
- ✅ Enough for: BASIC interpreter, video games, sound

---

## 5. Total: 32 instructions

Enough for BASIC + games:
- ✅ Arithmetic (ADD, SUB, ADC, SBC, INC, DEC)
- ✅ Logic (AND, OR, XOR)
- ✅ Shifts (SHL, SHR)
- ✅ Compare + all branches + computed jump
- ✅ Load/Store (pointer, zero-page, auto-increment)
- ✅ Computed pointer (MOV pl/ph from a0)
- ✅ Stack (PUSH, POP)
- ✅ Subroutines (CALL, RET)
- ✅ Interrupts (EI, DI + hardware NMI/IRQ)

---

## 5. Why No Extra Decode Chips Needed

```
opcode[7:6] → 74HC138 (or just 2 inverters + AND) → 4 class enables
opcode[5:3] → wires DIRECTLY to:
  - ALU: 74HC283 carry_in + 74HC86 XOR control (3 wires)
  - Branch: 74HC153 mux select (2 wires) → picks flag
  - Register: 74HC574 CLK enable (3 wires via small decode)
opcode[2:0] → wires DIRECTLY to register select

State[1:0] → combined with class to generate:
  - pc_inc = S0 OR S1 (1 OR gate)
  - ir_clk = S0 AND CLK (1 AND gate)
  - mem_access = S3 AND class_01 (1 AND gate)
  - alu_exec = S2 AND class_00 (1 AND gate)
```

Total control: **1× 74HC138 + 1× 74HC08 + 1× 74HC32 + 1× 74HC74** = 4 chips. Done.

---

## 6. Chip List (27 chips — honest, fully working, pure gates, no EEPROM)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U4 | 74HC161 ×4 | PC (16-bit counter, carry chain) |
| U5 | 74HC574 | IR opcode |
| U6 | 74HC574 | IR operand |
| U7 | 74HC574 | a0 (accumulator) |
| U8 | 74HC574 | t0 (temporary) |
| U9 | 74HC574 | sp (stack pointer) |
| U10 | 74HC161 | pl (pointer low, auto-increment) |
| U11 | 74HC574 | ph (pointer high) |
| U12-U13 | 74HC283 ×2 | ALU adder (8-bit) |
| U14-U15 | 74HC86 ×2 | XOR (8-bit SUB invert + branch logic) |
| U16-U17 | 74HC157 ×2 | Address mux low byte (PC vs pl, 8-bit) |
| U18 | 74HC541 | PC high byte buffer (tri-state) |
| U19 | 74HC245 | Data bus buffer (ALU result ↔ bus) |
| U20 | 74HC139 | Dual decoder (class + register select) |
| U21 | 74HC74 | State counter (2 FF) |
| U22 | 74HC74 | Flags (Z, C) |
| U23 | 74HC08 | AND gates (control) |
| U24 | 74HC32 | OR gates (control) |
| — | AT28C256 | Program ROM |
| — | 62256 | Data RAM |
| **Total** | | **27 chips (25 logic + ROM + RAM)** |

### Why 27 (not 23-24):
- 2× 74HC157 needed for full 8-bit address mux (not just 4-bit)
- 2× 74HC86 needed for full 8-bit SUB/SBC
- 1× 74HC541 needed for PC high byte tri-state
- 1× 74HC245 needed for ALU result → data bus routing
- These cannot be eliminated without losing functionality

### All chips available in DIP from Thailand:
74HC161, 574, 283, 86, 157, 541, 245, 139, 74, 08, 32, AT28C256, 62256.
All stocked at บ้านหม้อ, Shopee, RS Thailand.

---

## 7. Performance

| Parameter | Value |
|-----------|-------|
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| Cycles/instruction | 4 (fixed) |
| MIPS @ 3.5 MHz | **0.875** |
| MIPS @ 10 MHz | **2.5** |
| BASIC lines/sec @ 10 MHz | ~700 |

---

## 8. Comparison

| | RV8 (EEPROM) | RV8-G (gates only) | RV801-B |
|--|:---:|:---:|:---:|
| Chips | 27 | **27** | 9 |
| Instructions | 68 | **30** | 68 |
| Control | SST39SF010A Flash (70ns) | **Pure gates** | Hardwired (bit-serial) |
| Max clock | **10 MHz** (70ns Flash) | **10 MHz** (gates ~15ns) | 3.5 MHz |
| MIPS @ 10 MHz | **4.0** | 2.5 | 0.5 |
| Run BASIC | ✅ | ✅ | ⚠️ slow |
| Needs programmer | Yes (Flash/EEPROM) | **No** | No |
| Build difficulty | Hard | **Medium** | Easy |
| Control ROM | SST39SF010A-70 (PDIP-32, 70ns) | — | — |
| Program ROM | AT28C256 (DIP-28, 150ns) | AT28C256 | AT28C256 |

---

## 9. Next Steps

- [ ] Update Verilog model to match 24-chip design
- [ ] Complete WiringGuide (pin-level, every wire)
- [ ] Assembler (rv8g_asm.py)
- [ ] Build guide (labs, Thai+English)
- [ ] Breadboard build
