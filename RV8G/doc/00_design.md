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

## 3. Instruction Set (~24 instructions)

### Class 00: ALU (opcode[5:3] = ALU op, opcode[2:0] = source)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 00_000_000 | ADD t0 | a0 ← a0 + t0 |
| 00_001_000 | SUB t0 | a0 ← a0 - t0 |
| 00_010_000 | AND t0 | a0 ← a0 & t0 |
| 00_011_000 | OR t0 | a0 ← a0 \| t0 |
| 00_100_000 | XOR t0 | a0 ← a0 ^ t0 |
| 00_101_000 | CMP t0 | flags ← a0 - t0 |
| 00_110_000 | INC | a0 ← a0 + 1 |
| 00_111_000 | DEC | a0 ← a0 - 1 |
| 00_000_001 | ADDI imm | a0 ← a0 + imm |
| 00_001_001 | SUBI imm | a0 ← a0 - imm |
| 00_010_001 | ANDI imm | a0 ← a0 & imm |
| 00_011_001 | ORI imm | a0 ← a0 \| imm |
| 00_100_001 | XORI imm | a0 ← a0 ^ imm |
| 00_101_001 | CMPI imm | flags ← a0 - imm |

opcode[0] = 0: source is register (t0), 1: source is immediate (operand byte)
opcode[5:3] wires directly to ALU op select (74HC283 carry + 74HC86 XOR control)

### Class 01: Load/Store (opcode[5:3] = mode, opcode[2:0] = register)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 01_000_000 | LI a0, imm | a0 ← imm |
| 01_000_001 | LI t0, imm | t0 ← imm |
| 01_000_010 | LI sp, imm | sp ← imm |
| 01_001_000 | LB (ptr) | a0 ← RAM[{ph, pl}] |
| 01_001_001 | SB (ptr) | RAM[{ph, pl}] ← a0 |
| 01_010_000 | LI pl, imm | pl ← imm |
| 01_010_001 | LI ph, imm | ph ← imm |
| 01_011_000 | LB zp:imm | a0 ← RAM[{$00, imm}] |
| 01_011_001 | SB zp:imm | RAM[{$00, imm}] ← a0 |

opcode[2:0] wires directly to register select mux.

### Class 10: Branch/Jump (opcode[5:3] = condition)

| Opcode | Mnemonic | Condition |
|:------:|----------|-----------|
| 10_000_xxx | BEQ off | Z=1 |
| 10_001_xxx | BNE off | Z=0 |
| 10_010_xxx | BCS off | C=1 |
| 10_011_xxx | BCC off | C=0 |
| 10_100_xxx | BMI off | N=1 |
| 10_101_xxx | BPL off | N=0 |
| 10_110_xxx | BRA off | always |
| 10_111_xxx | JMP imm | PC ← {ph, imm} |

opcode[5:3] selects which flag to test — wires directly to a 74HC151 (8:1 mux) or 74HC153 (4:1 mux) that picks the condition.

### Class 11: System (opcode[5:3] = operation)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 11_000_xxx | PUSH a0 | sp--, RAM[{$30,sp}] ← a0 |
| 11_001_xxx | POP a0 | a0 ← RAM[{$30,sp}], sp++ |
| 11_010_xxx | CALL imm | push PC, PC ← {ph, imm} |
| 11_011_xxx | RET | pop PC |
| 11_100_xxx | NOP | no operation |
| 11_101_xxx | HLT | halt |
| 11_110_xxx | EI | enable interrupts |
| 11_111_xxx | DI | disable interrupts |

---

## 4. Total: 24 instructions

Enough for BASIC:
- ✅ Arithmetic (ADD, SUB, INC, DEC)
- ✅ Logic (AND, OR, XOR)
- ✅ Compare + all branches
- ✅ Load/Store (pointer, zero-page, immediate)
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

## 6. Chip List (22 chips)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U4 | 74HC161 ×4 | PC (16-bit counter) |
| U5 | 74HC574 | IR opcode |
| U6 | 74HC574 | IR operand |
| U7 | 74HC574 | a0 (accumulator) |
| U8 | 74HC574 | t0 (temporary) |
| U9 | 74HC574 | sp (stack pointer) |
| U10-U11 | 74HC161 ×2 | Pointer (pl, ph with auto-inc) |
| U12 | 74HC283 | ALU adder low |
| U13 | 74HC283 | ALU adder high |
| U14 | 74HC86 | XOR (SUB + XOR op) |
| U15-U16 | 74HC157 ×2 | Address mux (PC/pointer) |
| U17 | 74HC138 | Class decode (opcode[7:6]) |
| U18 | 74HC74 | State (2 FF) + flags (Z, C) |
| U19 | 74HC08 | AND (control gates) |
| U20 | 74HC32 | OR (control gates) |
| U21 | 74HC245 | Bus buffer |
| — | AT28C256 | ROM (program) |
| — | 62256 | RAM (data) |
| **Total** | | **22 chips** (20 logic + ROM + RAM) |

---

## 7. Performance

| Parameter | Value |
|-----------|-------|
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| Cycles/instruction | 3 (no memory) or 4 (with memory) |
| Avg cycles | ~3.3 |
| MIPS @ 3.5 MHz | **1.06** |
| MIPS @ 10 MHz | **3.03** |
| BASIC lines/sec @ 10 MHz | ~850 |

---

## 8. Comparison

| | RV8 (EEPROM) | RV8-G (gates only) | RV801-B |
|--|:---:|:---:|:---:|
| Chips | 27+ | **22** | 9 |
| Instructions | 68 | **24** | 68 |
| Control | EEPROM microcode | **Pure gates** | Hardwired (bit-serial) |
| MIPS @ 10 MHz | 4.0 | **3.03** | 0.5 |
| Run BASIC | ✅ | ✅ | ⚠️ slow |
| Needs programmer | Yes (EEPROM) | **No** | No |
| Elegance | Complex | **Simple** | Ultra-minimal |

---

## 9. Can 24 Instructions Really Run BASIC?

Yes. Here's a BASIC `PRINT 2+3` in RV8-G assembly:

```asm
; BASIC interpreter reads "2+3" from program text
LI ph, $08         ; point to BASIC text page
LI pl, $00         ; start of program
LB (ptr)           ; read '2' → a0 = $32 (ASCII)
SUBI $30           ; convert ASCII → number: a0 = 2
PUSH a0            ; save on stack
LB (ptr)           ; read '+' → a0 = $2B
; (interpreter recognizes '+', reads next number)
LB (ptr)           ; read '3' → a0 = $33
SUBI $30           ; a0 = 3
POP t0             ; t0 = 2 (from stack... wait, POP goes to a0)
```

Hmm — need `MOV t0, a0` or `POP t0`. Let me add MOV:

**Add 1 more instruction**: `MOV t0, a0` (opcode 00_111_001) — reuse ALU class with op=PASS.

**Revised: 25 instructions.** Still fits in the same decode.

---

## 10. Next Steps

- [ ] Finalize opcode encoding (exact bit assignments)
- [ ] Verify control logic fits in 4 gate chips (trace every signal)
- [ ] Write Verilog model
- [ ] Testbench
- [ ] WiringGuide (full pin-level, no ambiguity)
