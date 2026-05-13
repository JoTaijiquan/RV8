# RV808 — Design Notes (Multiplexed 8-bit Bus Variant)

**Status**: Exploration / brainstorming
**Date**: 2026-05-13

---

## Core Idea

Same ISA as RV8 (68 instructions, 2-byte fixed format), but with an 8-bit multiplexed address bus instead of 16-bit parallel. The ISA already treats addresses as two 8-bit halves — make the hardware match.

---

## Bus Architecture: Option B (Separate A + D)

```
A[7:0]  — 8 address lines (multiplexed high/low)
D[7:0]  — 8 data lines (always data)
ALE     — Address Latch Enable (pulses to capture address byte)
/RD     — Read strobe
/WR     — Write strobe
CLK     — System clock
/RST    — Reset
/NMI    — Non-maskable interrupt
/IRQ    — Maskable interrupt
VCC     — +5V
GND     — Ground
─────────────────────────
Total: ~20 pins
```

---

## Key Insight: Auto-Latch

Whenever ph, pl, sp, or pg changes (via LI, INC16, DEC16, ptr+), the hardware automatically drives the new value onto A[7:0] and pulses ALE to update the external address latch.

Result: by the time LB/SB executes, the address is already set up. Data access = 1 cycle.

---

## Address Sources (same as RV8, but latched externally)

| Source | High byte | Low byte | When latched |
|--------|-----------|----------|--------------|
| PC | PCH | PCL | Every fetch (automatic) |
| Pointer | ph | pl | On LI ph/pl, INC16, ptr+ |
| Stack | $30 | sp | On LI sp, PUSH/POP |
| Zero-page | $00 | imm | During execute (from operand) |
| Page | pg | imm | On LI pg + during execute |
| Vector | $FF | vector_lo | During interrupt |

---

## State Machine (revised for multiplexed bus)

### Fetch (every instruction, 2 bytes):

```
Fetch opcode:
  FC0: A ← PCL, ALE pulse (latch low address)
  FC1: A ← PCH, /RD assert → D = opcode, latch to IR, PC++

Fetch operand:
  FC2: A ← PCL, ALE pulse (latch low address — PCL already incremented)
  FC3: A ← PCH, /RD assert → D = operand, latch to IR, PC++

Total fetch: 4 cycles
```

### Execute (depends on instruction type):

```
ALU/LI/shift/branch/skip/NOP:
  EX: execute (combinational), write result
  Total: 4 + 1 = 5 cycles

  Special: if LI ph/pl/sp/pg → also drive A bus + ALE (free, same cycle)

LB (ptr) — address already latched from previous LI ph/pl or ptr+:
  EX: /RD assert → D = memory data → latch to register
  Total: 4 + 1 = 5 cycles

LB (ptr) — address NOT pre-latched (cold access):
  M0: A ← pl, ALE pulse
  M1: A ← ph, /RD → D = data → register
  Total: 4 + 2 = 6 cycles

SB (ptr) — address pre-latched:
  EX: D ← register, /WR pulse
  Total: 4 + 1 = 5 cycles

PUSH (pre-decrement sp, write):
  M0: sp--, A ← sp, ALE pulse (low, high=$30 hardwired)
  M1: A ← $30, D ← data, /WR pulse
  Total: 4 + 2 = 6 cycles

POP (read, post-increment sp):
  M0: A ← sp, ALE pulse
  M1: A ← $30, /RD → D = data → register, sp++
  Total: 4 + 2 = 6 cycles
```

### Optimization: Pre-latch tracking

Hardware tracks whether the address latch is "valid" for the current pointer:

```
addr_valid flag:
  Set when: LI ph, LI pl, INC16, DEC16, ptr+ completes
  Cleared when: any non-pointer address access occurs (stack, zp, pg, vector)

If addr_valid:
  LB (ptr) = 1 cycle (just /RD)
If !addr_valid:
  LB (ptr) = 2 cycles (latch + /RD)
```

This is optional complexity. Simpler: always do 2-cycle access, don't track.

---

## Performance Estimates

### Simple model (no pre-latch optimization):

| Instruction type | Cycles |
|-----------------|:------:|
| ALU reg, ALU imm, LI, shift, MOV | 5 |
| Branch not taken | 5 |
| Branch taken | 5 + 2 (re-fetch from new PC) = 7 |
| LB/SB (ptr) | 6 |
| LB/SB (ptr+) | 7 (access + increment + re-latch) |
| PUSH/POP | 6 |
| JAL | 10 (push PCH + push PCL + jump) |
| RET | 8 (pop PCL + pop PCH + fetch) |

Average: ~5.5 cycles/instruction

| Clock | MIPS |
|:-----:|:----:|
| 3.5 MHz (breadboard) | 0.64 |
| 10 MHz (PCB) | 1.82 |

### With pre-latch optimization:

Sequential pointer access (common in loops):
- First LB (ptr): 6 cycles
- Subsequent LB (ptr+): 5 cycles (addr already valid, just increment+read)

Average drops to ~5.0 cycles → **2.0 MIPS @ 10 MHz**

---

## Chip List (CPU Board)

| U# | Chip | Function |
|:--:|------|----------|
| U1 | 74HC161 | PCL (low counter) |
| U2 | 74HC161 | PCH (high counter) |
| U3 | 74HC574 | IR opcode |
| U4 | 74HC574 | IR operand |
| U5 | 74HC574 | a0 (accumulator) |
| U6 | 74HC574 | t0 (temporary) |
| U7 | 74HC574 | sp (stack pointer) |
| U8 | 74HC574 | pg (page register) |
| U9 | 74HC161 | pl (pointer low, countable) |
| U10 | 74HC161 | ph (pointer high, countable) |
| U11 | 74HC283 | ALU adder low nibble |
| U12 | 74HC283 | ALU adder high nibble |
| U13 | 74HC86 | XOR (SUB invert + XOR op) |
| U14 | 74HC138 | Instruction decode |
| U15 | 74HC74 | Flags (Z, C) |
| U16 | 74HC74 | State + N flag |
| U17 | 74HC08 | AND control logic |
| U18 | 74HC32 | OR control logic |
| U19 | 74HC245 | Bus buffer (D[7:0] direction) |
| — | — | **19 chips total** |

### What drives A[7:0]?

Need a mux to select what goes on the address output pins:
- PCL, PCH, pl, ph, sp, $30, $00, pg, imm, $FF

That's a lot of sources. Options:

1. **74HC157 ×2** (4:1 mux, need 2 for 8-bit) — adds 2 chips → 21 total
2. **Tri-state outputs** — each register has /OE, only one drives A bus at a time
   - 74HC574 already has /OE! Just enable the right one.
   - 74HC161 outputs are always on... need buffer or use 74HC593 instead

Option 2 is elegant: registers already have tri-state. Just decode which one drives A[7:0]:

```
addr_src decode → enables one of:
  PCL./OE, PCH./OE, pl./OE, ph./OE, sp./OE, pg./OE, operand./OE
  + hardwired $30/$00/$FF via pull-up/pull-down + buffer
```

Problem: 74HC161 (PC, pointer) doesn't have /OE. Solutions:
- Use 74HC593 (8-bit counter with tri-state output) instead — but it's 1 chip per 8 bits
- Add 74HC245 buffers on PC/pointer outputs
- Use 74HC574 for PC too (load from bus, no counting) — but then PC increment needs ALU

**Simplest: add 1× 74HC245 as address output buffer** — all internal sources mux onto internal bus, then 74HC245 drives A[7:0] externally.

Wait — we already have U19 (74HC245) for D[7:0]. Need a second one for A[7:0].

Revised: **U19 = data bus buffer, U20 = address bus buffer** → 20 chips.

Or: use the internal data bus for address too (time-multiplexed internally):

```
Internal 8-bit bus carries everything:
  - Register values
  - ALU results  
  - Address bytes (to external A pins via buffer)
  - Data bytes (to/from external D pins via buffer)
```

Single internal bus, two external buffers. This is the 8085 model.

---

## Revised Chip List (with address buffer)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U2 | 74HC161 ×2 | PC (with /OE buffer or use 574) |
| U3-U4 | 74HC574 ×2 | IR opcode + operand |
| U5-U8 | 74HC574 ×4 | a0, t0, sp, pg |
| U9-U10 | 74HC161 ×2 | pl, ph (pointer) |
| U11-U13 | 74HC283 ×2 + 74HC86 | ALU |
| U14 | 74HC138 | Instruction decode |
| U15-U16 | 74HC74 ×2 | Flags + state |
| U17-U18 | 74HC08 + 74HC32 | Control logic |
| U19 | 74HC245 | Data bus buffer (D[7:0]) |
| U20 | 74HC245 | Address bus buffer (A[7:0]) |
| — | — | **20 chips** |

---

## Memory Board

| Chip | Function |
|------|----------|
| 74HC574 | Address low latch (captures A[7:0] on ALE1) |
| 74HC574 | Address high latch (captures A[7:0] on ALE2) |
| 74HC138 | Address decode (ROM/RAM/IO select) |
| AT28C256 | Program ROM |
| 62256 | Data RAM |
| — | **5 chips** |

---

## System Total: 25 chips (20 CPU + 5 memory)

vs RV8: 26 chips (but 40-pin bus, harder wiring)

---

## Open Questions

1. Can we eliminate the address buffer (U20) by using tri-state register outputs directly?
2. Should PC use 74HC574 (loadable, no count) + ALU for increment? Saves needing /OE on counters.
3. Is pre-latch optimization worth the extra state logic?
4. Should we add new instructions that exploit the bus model?
   - `LBA imm` — load byte from address {pg, imm} in one instruction?
   - Already exists as `LB pg:imm` in current ISA!
5. Can fetch be overlapped with execute? (pipeline)
6. Do we need the constant generator (c0) or can we free those opcodes?

---

## Possible ISA additions for RV808

| Instruction | Encoding | Effect | Benefit |
|-------------|----------|--------|---------|
| `LDB (pg+)` | new opcode | a0 ← mem[{pg, offset++}] | Fast page-sequential read |
| `STB (pg+)` | new opcode | mem[{pg, offset++}] ← a0 | Fast page-sequential write |
| `LDBI imm` | new opcode | a0 ← mem[{pg, imm}] (same as existing) | — already exists |
| `CALL imm16` | 3-byte? | No — breaks 2-byte format | ❌ |
| `BANK n` | new opcode | Switch memory bank (for >64KB) | Future expansion |

---

## Comparison Summary

| | RV8 | RV808 |
|--|:---:|:---:|
| ISA | 68 instructions | 68 (same, maybe +2) |
| Bus pins | 40 | **~20** |
| CPU chips | 26 | **20** |
| Memory chips | (on CPU board) | 5 (separate board) |
| System total | 26 | **25** |
| Cycles/instr avg | 2.5 | 5.5 |
| MIPS @ 3.5 MHz | 1.4 | 0.64 |
| MIPS @ 10 MHz | 4.0 | **1.82** |
| Wiring difficulty | Hard | **Easy** |
| Software compatible | — | ✅ same programs |
| Breadboard friendly | Moderate | **Very** |

---

## Next Steps

- [ ] Decide: address buffer approach (U20 74HC245 vs tri-state registers)
- [ ] Decide: PC implementation (74HC161 counter vs 74HC574 + ALU increment)
- [ ] Detail the state machine (full state table)
- [ ] Verify timing at 10 MHz (propagation delays)
- [ ] Decide: pre-latch optimization (worth it?)
- [ ] Write Verilog model for RV808
- [ ] Decide: new instructions or keep 100% compatible

---

## CONCLUSION: Harvard approach selected

See `01_harvard_deep.md` for the detailed design.

Key numbers:
- 22 chips total (19 CPU + 3 memory board + ROM + RAM)
- 20-pin bus (vs 40-pin RV8)
- ~2.86 MIPS @ 10 MHz (runs BASIC + games)
- Same ISA philosophy, ~90% software compatible with RV8
- Fetch is internal (ROM on CPU board) — no bus penalty
- Data access via page:offset — 1 cycle when page is set
