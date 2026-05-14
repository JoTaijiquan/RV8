# RV808-G — Gates-Only Harvard CPU (20 chips)

**Constraint**: No EEPROM/microcode. Pure 74HC gates. Run BASIC + games.
**Relationship**: Gates-only variant of RV808 (Harvard fetch, page:offset data)
**Sister variant**: RV8-G (gates-only Von Neumann, 23 chips)

---

## Summary

| Parameter | Value |
|-----------|-------|
| Chips | **20** (18 logic + ROM + RAM) |
| Instructions | ~22 |
| Control | Pure 74HC gates (5 chips) |
| Architecture | Harvard (ROM internal, paged RAM) |
| States | 3-4 (S3-skip for non-memory) |
| MIPS @ 3.5 MHz | 1.06 |
| MIPS @ 10 MHz | **3.03** |
| Run BASIC | ✅ |
| Needs programmer | **No** (only ROM for programs) |

---

## Chip List (20)

| # | Chip | Function |
|:-:|------|----------|
| U1-U4 | 74HC161 ×4 | PC (16-bit) → ROM directly |
| U5-U6 | 74HC574 ×2 | IR (opcode + operand) ← ROM data |
| U7-U9 | 74HC574 ×3 | a0, t0, sp |
| U10 | 74HC574 | pg (page latch → RAM A[14:8]) |
| U11-U12 | 74HC283 ×2 | ALU adder (8-bit) |
| U13 | 74HC86 | XOR (SUB invert) |
| U14 | 74HC138 | Class decode (gated by S2) |
| U15-U16 | 74HC74 ×2 | State counter + flags (Z, C) |
| U17 | 74HC08 | AND gates (control) |
| U18 | 74HC32 | OR gates (control) |
| U19 | 74HC245 | Bus buffer (external I/O) |
| — | AT28C256 | ROM (code, internal fetch) |
| — | 62256 | RAM (data, paged) |

---

## Key Differences from RV8-G (23 chips)

| | RV8-G (23) | RV808-G (20) |
|--|:---:|:---:|
| ROM fetch | Via shared address bus | **Direct PC→ROM (no bus)** |
| Address mux | 2× 74HC157 | **None (removed)** |
| Pointer | pl, ph (2× 74HC161) | **pg page latch (1× 74HC574)** |
| Data addressing | Pointer {ph,pl} | **Page:offset {pg, imm/t0}** |
| Chips saved | — | **−3** |
| Speed | 2.5 MIPS | **3.03 MIPS** (S3-skip) |

---

## How It Works

```
Code fetch (internal, no bus traffic):
  PC[14:0] → ROM address pins (direct wires)
  ROM data → IR latch (direct wires)
  No bus contention. Fetch is free.

Data access (external, paged):
  pg register → RAM A[14:8] (page, rarely changes)
  operand/t0 → RAM A[7:0] (offset, from instruction)
  D[7:0] ↔ RAM data (read/write)

External bus (I/O only):
  Pages $80+ → expansion slots via 40-pin connector
```

---

## ISA (~22 instructions)

Same as RV8-G but replace pointer ops with page:offset:

| Class | Instructions |
|-------|-------------|
| ALU (00) | ADD, SUB, AND, OR, XOR, CMP, INC, DEC, ADDI, SUBI, ANDI, ORI, XORI, CMPI |
| LDST (01) | LI (a0,t0,sp,pg), LB pg:imm, SB pg:imm, LB pg:t0, SB pg:t0 |
| Branch (10) | BEQ, BNE, BCS, BCC, BMI, BPL, BRA, JMP |
| System (11) | PUSH, POP, CALL, RET, NOP, HLT, EI, DI |

---

## Comparison (full family)

| | RV801-B | RV8-G | RV808-G | RV8 | RV808 |
|--|:---:|:---:|:---:|:---:|:---:|
| Chips | 9 | 23 | **20** | 26+ | 23+ |
| Control | Hardwired | Gates | **Gates** | EEPROM | EEPROM |
| MIPS@10 | 0.5 | 2.5 | **3.0** | 4.0 | 2.86 |
| Instructions | 68 | 25 | 22 | 68 | 67 |
| BASIC | ⚠️ slow | ✅ | ✅ | ✅ | ✅ |
| Programmer needed | No | No | **No** | Yes | Yes |
