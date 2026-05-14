# RV808 Harvard — Deep Design

**Date**: 2026-05-13
**Concept**: Harvard-ish 8-bit CPU with internal ROM fetch + external 8-bit data bus

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│  CPU BOARD                                            │
│                                                       │
│  ┌─────┐    ┌─────┐    ┌─────┐                      │
│  │ PC  │───→│ ROM │───→│ IR  │                       │
│  │16bit│    │32KB │    │op+op│                       │
│  └──┬──┘    └─────┘    └──┬──┘                       │
│     │                      │                          │
│     │    ┌─────────────────┼──────────────┐          │
│     │    │    INTERNAL 8-BIT BUS          │          │
│     │    ├─────┬─────┬─────┬─────┬───────┤          │
│     │    │ a0  │ t0  │ sp  │ pg  │ ALU   │          │
│     │    └─────┴─────┴─────┴──┬──┴───────┘          │
│     │                          │                      │
│     │              ┌───────────┼───────────┐         │
│     │              │  A[7:0]   │  D[7:0]   │         │
│     │              │  (from    │  (buffer)  │         │
│     │              │  operand  │            │         │
│     │              │  or reg)  │            │         │
│     │              └─────┬─────┴─────┬──────┘         │
└─────┼────────────────────┼───────────┼───────────────┘
      │                    │           │
      │ (internal)         │           │
      │                    ▼           ▼
                    ┌──────────────────────────┐
                    │  EXTERNAL DATA BUS       │
                    │  18 pins                 │
                    │  A[7:0] D[7:0] /PG_WR   │
                    │  /RD /WR CLK /RST       │
                    │  /NMI /IRQ VCC GND      │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────┴─────────────┐
                    │  MEMORY BOARD             │
                    │  PAGE latch → A[15:8]    │
                    │  A[7:0] bus → A[7:0]    │
                    │  RAM 32KB               │
                    │  I/O decode              │
                    └──────────────────────────┘
```

---

## 2. Bus Definition (18 pins)

| Pin | Name | Direction | Function |
|:---:|------|:---------:|----------|
| 1-8 | A[7:0] | CPU→out | Address low byte (offset within page) |
| 9-16 | D[7:0] | bidirectional | Data read/write |
| 17 | /PG_WR | CPU→out | Page register write strobe |
| 18 | /RD | CPU→out | Read strobe |
| 19 | /WR | CPU→out | Write strobe |
| 20 | CLK | CPU→out | System clock |
| 21 | /RST | CPU→out | Reset |
| 22 | /NMI | in→CPU | Non-maskable interrupt |
| 23 | /IRQ | in→CPU | Maskable interrupt |
| 24 | VCC | power | +5V |
| 25 | GND | power | Ground |

**25-pin bus** (or 20 if we combine some signals). Could use a DB-25 connector or 2×13 pin header.

---

## 3. How Fetch Works (Internal — no bus traffic)

```
PC (16-bit counter) → ROM address pins directly (on-board wiring)
ROM data out → IR latch

Fetch cycle:
  F0: ROM[PC] → IR_opcode, PC++
  F1: ROM[PC] → IR_operand, PC++

2 cycles to fetch. NO external bus used.
ROM is always reading (directly wired to PC).
```

This is the key advantage: fetch never touches the external bus.
The bus is 100% available for data access.

---

## 4. Memory Model

### CPU sees two separate spaces:

```
CODE SPACE (internal ROM, 32KB):
  $0000-$7FFF  Program code (fetched by PC)
  Vectors at top: $7FF6-$7FFF (TRAP, NMI, RESET, IRQ)

DATA SPACE (external bus, 64KB = 256 pages × 256 bytes):
  Page $00:     Zero-page variables (256 bytes)
  Page $01:     Stack (256 bytes, SP-relative)
  Page $02-$03: Screen buffer (512 bytes for 40×25 + attributes)
  Page $04-$07: I/O ports (1KB window)
  Page $08-$7F: General RAM (30KB — BASIC program text, strings, arrays)
  Page $80-$FF: Extended RAM or banked (future)
```

### Key insight: code and data are SEPARATE

- Code lives in ROM (read-only, fast, internal)
- Data lives in RAM (read/write, external bus)
- No self-modifying code (acceptable for BASIC + games)
- BASIC program text is DATA (stored in RAM, interpreted from ROM)

### How BASIC works in this model:

```
ROM contains:  BASIC interpreter (machine code)
RAM contains:  User's BASIC program (text: "10 PRINT HELLO")

Interpreter in ROM reads RAM to get BASIC tokens:
  PAGE $08        ; point to BASIC text area
  LB pg:offset    ; read next character of BASIC program
  ; parse, execute...
```

---

## 5. Addressing Modes (revised for Harvard)

| Mode | Syntax | Address | Cycles | Use case |
|------|--------|---------|:------:|----------|
| Page:offset | `LB pg:imm` | {pg, imm8} | 1 | Primary data access |
| Zero-page | `LB zp:imm` | {$00, imm8} | 1 | Fast variable access |
| Stack | `LB sp+imm` | {$01, sp+imm8} | 1 | Local variables |
| Pointer | `LB (ptr)` | {ph, pl} | 1* | Indirect access |
| Pointer+ | `LB (ptr+)` | {ph, pl}, pl++ | 1* | Sequential scan |
| I/O | `IN port` / `OUT port` | {$04, port} | 1 | Hardware I/O |

*Pointer mode: if ph:pl matches current page latch, 1 cycle. If not, needs page switch (2 cycles).

### The page register flow:

```asm
; Access variable at $0042 (zero-page):
LB zp:$42          ; A[7:0] = $42, page latch already $00 → 1 cycle read

; Access BASIC text at $0800+:
PAGE $08            ; update page latch to $08 (1 cycle, /PG_WR pulse)
LB pg:$00           ; read first byte of BASIC program
LB pg:$01           ; read second byte — no page switch needed!
...                 ; continue reading within page $08 (256 bytes)
PAGE $09            ; next page
LB pg:$00           ; continue reading
```

---

## 6. Page Latch Behavior

On the memory board:

```
┌──────────────────────────────────────┐
│  PAGE LATCH (74HC574)                │
│                                      │
│  D[7:0] ← from data bus D[7:0]     │
│  CLK ← /PG_WR (active low pulse)   │
│  Q[7:0] → RAM A[15:8]              │
│  /OE ← GND (always driving)        │
│                                      │
│  Holds the "page" until next PG_WR  │
└──────────────────────────────────────┘

RAM address = {PAGE_LATCH[7:0], A[7:0] from bus}
            = full 16-bit address
```

Special pages hardwired:
- Zero-page ($00): could bypass latch (A[15:8] forced to $00 when ZP mode)
- Stack page ($01): A[15:8] forced to $01 when stack mode
- Or: just use the page latch for everything (simpler, software sets page)

---

## 7. State Machine

### States:

```
F0: Fetch opcode  — ROM[PC] → IR_opcode, PC++
F1: Fetch operand — ROM[PC] → IR_operand, PC++
EX: Execute       — ALU/register/branch (1 cycle)
M1: Memory read   — A=offset, /RD, D→register (1 cycle)
M2: Memory write  — A=offset, D=data, /WR (1 cycle)
PG: Page write    — D=pg_value, /PG_WR (1 cycle)
S1-S4: Stack ops  — push/pop sequences
```

### Instruction timing:

| Type | States | Total cycles | Examples |
|------|--------|:------------:|---------|
| ALU/LI/shift/MOV | F0,F1,EX | **3** | ADD, ADDI, LI a0, SHL |
| Branch (not taken) | F0,F1,EX | **3** | BNE (Z=0) |
| Branch (taken) | F0,F1,EX,F0,F1 | **3** (+refetch) | BNE (Z=1) — PC loaded, refetch |
| PAGE set | F0,F1,PG | **3** | PAGE $xx |
| LB (data read) | F0,F1,EX,M1 | **4** | LB pg:imm, LB zp:imm |
| SB (data write) | F0,F1,EX,M2 | **4** | SB pg:imm |
| LB (ptr) | F0,F1,M1 | **3** | pointer already set |
| LB (ptr+) | F0,F1,M1,EX | **4** | read + increment pointer |
| PUSH | F0,F1,EX,M2 | **4** | sp--, write to stack |
| POP | F0,F1,M1,EX | **4** | read from stack, sp++ |
| JAL | F0,F1,M2,M2,EX | **5** | push PCH, push PCL, jump |
| RET | F0,F1,M1,M1,EX | **5** | pop PCL, pop PCH, load PC |

### Average cycles per instruction: ~3.5

Compare:
- RV8: ~2.5 cycles/instruction
- RV808 mux: ~5.5 cycles/instruction
- **RV808 Harvard: ~3.5 cycles/instruction** ← much better than mux!

### Performance:

| Clock | MIPS | BASIC lines/sec |
|:-----:|:----:|:---------------:|
| 3.5 MHz | 1.0 | ~280 |
| 10 MHz | **2.86** | **~800** |
| 20 MHz (PCB) | 5.7 | ~1600 |

At 10 MHz this is **faster than RV8 on breadboard** and runs BASIC comfortably.

---

## 8. Fetch Detail (Internal ROM)

```
        PC[15:0]
           │
     ┌─────┴─────┐
     │  AT28C256  │
     │   (ROM)    │
     │            │
     │  A[14:0]←PC│
     │  D[7:0]→──┼──→ IR input
     │  /OE ← GND│
     │  /CE ← GND│
     └───────────┘

PC drives ROM address pins DIRECTLY (no bus, no mux).
ROM output goes directly to IR latch input.
IR_opcode latches on F0 clock edge.
IR_operand latches on F1 clock edge.

PC increments via 74HC161 carry chain (free, no ALU needed).
```

ROM access time: 150ns (AT28C256-15). At 10 MHz (100ns cycle), need faster ROM:
- AT28C256-15: 150ns ← too slow for 10 MHz!
- SST39SF010: 70ns ← works at 10 MHz
- W27C512: 45ns ← works at 20 MHz
- Or: use 3.5 MHz on breadboard (286ns cycle, plenty of margin)

For breadboard @ 3.5 MHz: AT28C256 is fine (150ns < 286ns).
For PCB @ 10 MHz: use SST39SF010 or similar fast flash.

---

## 9. Data Access Detail (External Bus)

### Read (LB pg:imm):

```
EX state:
  A[7:0] ← IR_operand (the imm8 offset)
  (page latch already holds pg value from earlier PAGE instruction)
  
M1 state:
  /RD asserts
  RAM sees: address = {page_latch, A[7:0]} = full 16-bit
  RAM outputs data on D[7:0]
  CPU latches D[7:0] into destination register
  /RD deasserts
```

### Write (SB pg:imm):

```
EX state:
  A[7:0] ← IR_operand
  D[7:0] ← source register (a0)

M2 state:
  /WR pulses
  RAM captures D[7:0] at address {page_latch, A[7:0]}
```

### Page switch (PAGE imm):

```
EX/PG state:
  D[7:0] ← IR_operand (the new page number)
  /PG_WR pulses
  External page latch captures new value
  Also: internal pg register updated
```

One cycle cost. Then all subsequent accesses use the new page.

---

## 10. CPU Board Chip List

| U# | Chip | Function | Notes |
|:--:|------|----------|-------|
| U1 | 74HC161 | PCL (bit 3:0) | Carry → U2 |
| U2 | 74HC161 | PCL (bit 7:4) | Carry → U3 |
| U3 | 74HC161 | PCH (bit 11:8) | Carry → U4 |
| U4 | 74HC161 | PCH (bit 15:12) | For 32KB ROM, only need 15 bits |
| U5 | 74HC574 | IR opcode | Latches from ROM D[7:0] |
| U6 | 74HC574 | IR operand | Latches from ROM D[7:0] |
| U7 | 74HC574 | a0 (accumulator) | /OE for internal bus drive |
| U8 | 74HC574 | t0 (temporary) | /OE for internal bus drive |
| U9 | 74HC574 | sp (stack pointer) | /OE for internal bus drive |
| U10 | 74HC574 | pg (page register) | /OE + drives D bus for PG_WR |
| U11 | 74HC283 | ALU adder low nibble | |
| U12 | 74HC283 | ALU adder high nibble | |
| U13 | 74HC86 | XOR (SUB/XOR ops) | |
| U14 | 74HC138 | Instruction decode | |
| U15 | 74HC74 | Flags Z, C | |
| U16 | 74HC74 | State + N flag | |
| U17 | 74HC08 | AND control logic | |
| U18 | 74HC32 | OR control logic | |
| U19 | 74HC245 | D[7:0] bus buffer | Bidirectional, /OE controlled |
| — | AT28C256 | Program ROM (32KB) | Directly wired to PC |
| **Total** | | **19 chips + ROM** | |

### What about pointer (pl, ph)?

In RV8 we have pl/ph as 74HC161 counters for ptr+ auto-increment.

Options for RV808:
- **Option A**: Keep pl/ph as 74HC574 registers. ptr+ uses ALU to increment. (+0 chips, costs 1 cycle)
- **Option B**: Keep pl/ph as 74HC161 counters. Need buffer to drive A bus. (+2-3 chips)
- **Option C**: Eliminate pl/ph. Use pg:imm for everything. (saves 2 chips, less flexible)

**Option A is best**: pl and ph are just registers. The `pg:imm` mode handles most access. Pointer mode is rare (only for indirect/sequential). Spending 1 extra cycle on ptr+ is fine.

But wait — if we eliminate pl/ph as separate registers and just use pg + a counter...

Actually, let's keep it simple: **pg IS the page, operand IS the offset**. No separate pointer registers needed for most code:

```asm
; Sequential read (BASIC text scanning):
PAGE $08          ; set page
LB pg:$00         ; read byte 0
LB pg:$01         ; read byte 1
LB pg:$02         ; read byte 2
; ... compiler/assembler generates sequential offsets
```

For truly dynamic pointer access, use t0 as index:
```asm
; Indirect read via computed offset:
PAGE $08
ADD t0            ; a0 = base + index (computed offset)
; Hmm, can't use a0 as address...
```

Problem: we need a way to use a **register value** as the offset, not just an immediate.

### New addressing mode needed: `LB pg:reg`

```asm
LB pg:t0          ; read from {pg, t0} — offset comes from register
```

This enables:
```asm
PAGE $08
LI t0, $00
loop:
  LB pg:t0       ; read byte at {$08, t0}
  ; process byte...
  INC t0         ; next offset (was INC, now just t0++)
  BNE loop       ; loop until t0 wraps
  PAGE $09       ; next page
  LI t0, $00
  ; continue...
```

This replaces the ptr/ptr+ mode with pg:register mode. Cleaner!

---

## 11. Revised Register Set

| Register | Width | Purpose |
|----------|:-----:|---------|
| a0 | 8 | Accumulator (ALU result) |
| t0 | 8 | Temporary / index register |
| sp | 8 | Stack pointer (stack at page $01) |
| pg | 8 | Page register (drives external page latch) |

**Only 4 registers!** (was 7 in RV8)

Eliminated:
- ~~pl, ph~~ → replaced by pg:imm and pg:t0 modes
- ~~c0~~ → constant generator can stay (it's just decode logic, no register chip)

This saves 2× 74HC574 (pl, ph) → **CPU board = 17 chips + ROM!**

---

## 12. Revised Chip List (minimal)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U4 | 74HC161 ×4 | PC (16-bit counter) |
| U5-U6 | 74HC574 ×2 | IR (opcode + operand) |
| U7 | 74HC574 | a0 |
| U8 | 74HC574 | t0 |
| U9 | 74HC574 | sp |
| U10 | 74HC574 | pg |
| U11-U12 | 74HC283 ×2 | ALU adder |
| U13 | 74HC86 | XOR |
| U14 | 74HC138 | Decode |
| U15-U16 | 74HC74 ×2 | Flags + state |
| U17-U18 | 74HC08 + 74HC32 | Control |
| U19 | 74HC245 | D bus buffer |
| — | AT28C256 | ROM |
| **Total** | | **19 chips + ROM** |

### What drives A[7:0]?

A[7:0] comes from:
- IR_operand (for pg:imm mode) — most common
- t0 register (for pg:t0 mode) — indexed access
- sp register (for stack access)

These are all 74HC574 with /OE. Use a small mux or just tri-state:

```
A[7:0] source select:
  addr_src = 00: IR_operand (U6 /OE enabled)
  addr_src = 01: t0 (U8 /OE enabled)  
  addr_src = 10: sp (U9 /OE enabled)
  addr_src = 11: (unused)
```

Wait — /OE on 574 controls the Q outputs. If we connect Q outputs to BOTH the internal bus AND the A[7:0] pins... that's a conflict.

Better: **A[7:0] is driven by a dedicated latch/buffer** that captures from the internal bus:

```
Internal bus → U20 (74HC574, address output latch, ALE-clocked) → A[7:0] pins
```

Add 1 chip: **U20 = address output latch**. Total: **20 chips + ROM**.

Or: route IR_operand (U6) outputs directly to A[7:0] pins (most common case), with a mux for t0/sp. Since U6 is already a 574 with dedicated outputs...

Actually simplest: **U6 (IR operand) Q outputs go directly to A[7:0]**. For the rare case of pg:t0 or stack access, use a 74HC157 mux between U6.Q and t0/sp.

Add: 1× 74HC157 (4-bit mux) — but need 8 bits... need 2× 74HC157.

Hmm, back to 21 chips. Let me reconsider...

**Cleanest: just use the internal bus + one output latch (U20)**:
- 20 chips + ROM
- Any register can drive A[7:0] via internal bus → U20 latch
- One extra cycle to latch address (but can overlap with other work)

---

## 13. Performance with BASIC

### Typical BASIC interpreter inner loop:

```asm
; Read next BASIC token from RAM
; (program text at page $08+, offset in t0)
scan_next:
    LB pg:t0        ; 4 cycles: fetch(2) + addr(1) + read(1)
    INC t0          ; 3 cycles: fetch(2) + execute(1)
    CMPI ' '        ; 3 cycles: compare with space
    BEQ scan_next   ; 3 cycles: branch if space (skip whitespace)
    ; total per char: 13 cycles
    ; at 10 MHz: 769K chars/sec
    ; BASIC line ~40 chars: 19K lines parsed/sec (overhead reduces to ~800 executed/sec)
```

### Game loop (Snake):

```asm
game_frame:
    ; Read input (1 I/O access)
    PAGE $04          ; 3 cycles
    LB pg:$00         ; 4 cycles — read keyboard port
    
    ; Update snake position (variables in page $00)
    PAGE $00          ; 3 cycles
    LB pg:snake_x     ; 4 cycles
    ADDI 1            ; 3 cycles
    SB pg:snake_x     ; 4 cycles
    
    ; Draw to screen (page $02)
    PAGE $02          ; 3 cycles
    LI t0, offset     ; 3 cycles
    SB pg:t0          ; 4 cycles — write character to screen
    
    ; ~34 cycles per minimal frame update
    ; at 10 MHz: 294K updates/sec — way more than 60fps needed
```

**BASIC and games work great.**

---

## 14. ISA Changes from RV8

| RV8 instruction | RV808 equivalent | Notes |
|-----------------|------------------|-------|
| LI ph, imm | PAGE imm | Sets page latch |
| LI pl, imm | (use t0 as index) | Or just use pg:imm directly |
| LB (ptr) | LB pg:t0 | Indirect via register offset |
| LB (ptr+) | LB pg:t0 + INC t0 | 2 instructions (was 1) |
| SB (ptr) | SB pg:t0 | Same pattern |
| LB zp:imm | LB zp:imm | Keep (page forced to $00) |
| LB sp+imm | LB sp:imm | Keep (page forced to $01) |
| INC16/DEC16/ADD16 | (eliminated) | No 16-bit pointer |
| All ALU ops | Same | Unchanged |
| All branches | Same | Unchanged |
| PUSH/POP | Same | Stack at page $01 |
| JAL/RET | Same | Unchanged |
| Interrupts | Same | Unchanged |

### New instructions:

| Instruction | Encoding | Effect |
|-------------|----------|--------|
| PAGE imm | [opcode][imm8] | pg ← imm, pulse /PG_WR |
| LB pg:t0 | [opcode][unused] | a0 ← RAM[{pg, t0}] |
| SB pg:t0 | [opcode][unused] | RAM[{pg, t0}] ← a0 |

### Instruction count:

RV8 has 68. RV808 removes ~6 (pointer ops) and adds ~3 = **~65 instructions**.

---

## 15. Memory Board Detail

| Chip | Function | Connections |
|------|----------|-------------|
| 74HC574 | Page latch | D←D[7:0], CLK←/PG_WR, Q→RAM A[15:8] |
| 74HC138 | Address decode | A←page[7:5], /Y→ROM_CE, RAM_CE, IO_CE |
| 62256 | RAM (32KB) | A[14:0]←{page[6:0], A[7:0]}, D←D[7:0] |
| — | (I/O connector) | directly on bus |
| **Total** | **3 chips + RAM** | |

Wait — no ROM on memory board (ROM is on CPU board). So memory board is just:
- 1× 74HC574 (page latch)
- 1× 74HC138 (decode — optional, for I/O separation)
- 1× 62256 (RAM)
- **3 chips + RAM**

---

## 16. System Total

| Board | Chips |
|-------|:-----:|
| CPU board | 19 + ROM |
| Memory board | 3 + RAM |
| **System total** | **22 + ROM + RAM = 24** |

vs RV8: 26 chips. **Saves 2 chips** with simpler wiring.

---

## 17. Trade-offs Summary

| | RV8 | RV808 Harvard |
|--|:---:|:---:|
| CPU chips | 26 | **22** (19+3) |
| Bus pins | 40 | **~20** |
| Fetch cycles | 2 | **2** (same! ROM is local) |
| Data access cycles | 1 | **1-2** (1 if page set, 2 if page switch) |
| Avg cycles/instr | 2.5 | **3.5** |
| MIPS @ 3.5 MHz | 1.4 | **1.0** |
| MIPS @ 10 MHz | 4.0 | **2.86** |
| BASIC @ 10 MHz | ~1100 lines/s | **~800 lines/s** |
| Wiring difficulty | Hard | **Easy** |
| Self-modifying code | ✅ | ❌ (Harvard) |
| Software compatible | — | ~90% (minor ISA changes) |
| Pointer operations | Fast (hardware counter) | Slightly slower (register + ALU) |
| Page-sequential access | N/A | Very fast (no page switch) |

---

## 18. Open Questions

1. **Do we need pl/ph at all?** pg:t0 covers most cases. Saves 2 chips.
2. **Stack page**: hardwire to $01, or let software choose? Hardwire is simpler.
3. **ROM programming**: ROM is on CPU board. Need a way to program it.
   - Option: programmer board connects to ROM directly (holds CPU in reset)
   - Same as RV8 programmer board concept
4. **Can we run code from RAM?** Not in pure Harvard. But could add a "RAM execute" mode
   where PC addresses RAM instead of ROM (bank switch). Useful for loading programs from SD.
5. **Interrupt vectors**: in ROM (fixed) or RAM (changeable)?
   - ROM: simpler, vectors are fixed addresses that jump to RAM-based handlers
   - RAM: more flexible but needs the page switch during interrupt
6. **Is 4 registers enough?** a0, t0, sp, pg. Compare: 6502 has A, X, Y (3 + SP).
   We have 4 general + SP. Should be fine.

---

## 19. Next Steps

- [ ] Finalize ISA (instruction encoding table)
- [ ] Detail the state machine (full state transition diagram)
- [ ] Decide: A[7:0] output method (direct from U6 vs latch)
- [ ] Decide: keep or drop pl/ph
- [ ] Write Verilog model
- [ ] Design memory board schematic
- [ ] Estimate BOM cost

---

## 20. Two Variants

### RV808 Lite (23 chips) — Harvard, separate code/data

```
Code: 16KB ROM (always) + 16KB switchable ROM/RAM
Data: 32KB RAM (paged, 128 pages × 256 bytes)
Fetch: internal (ROM on-board, free, no bus)
Bus: 17-pin (I/O only)
```

- Simplest build
- Fastest fetch (no bus contention)
- Code from RAM via overlay (PC[14] + RAM_EXEC bit, 0 extra chips)
- Best for breadboard + learning

### RV808 Full (25 chips) — Unified 64KB

```
Code: 16KB ROM (system, $0000-$3FFF) + 48KB RAM (code+data, $4000-$FFFF)
Data: same 48KB RAM (paged access)
Fetch: from ROM (direct) or RAM (via address mux)
Bus: 17-pin (I/O only)
Extra: +2× 74HC157 (RAM address mux: PC vs page:offset)
```

- Full unified memory (code and data share RAM)
- Self-modifying code works
- Load and run any program from SD/terminal
- Better for "production" single-board computer

### Upgrade path:

```
Build Lite first (23 chips) → learn, run BASIC, play simple games
Add 2× 74HC157 later → becomes Full (25 chips) → load native programs from SD
```

### Summary table:

| | RV808 Lite | RV808 Full | RV8 |
|--|:---:|:---:|:---:|
| Chips | **23** | 25 | 26 |
| Gates | ~590 | ~670 | ~720 |
| Bus pins | 17 | 17 | 40 |
| Code space | 32KB (ROM+overlay) | 64KB (ROM+RAM unified) | 64KB unified |
| Data space | 32KB RAM | 48KB RAM | 32KB RAM |
| Fetch penalty | 0 (ROM internal) | 0 (time-shared) | 0 |
| Self-mod code | Limited | ✅ | ✅ |
| MIPS @ 10 MHz | 2.86 | 2.86 | 4.0 |
| Wiring | Easy | Easy | Hard |
| Upgrade path | → Full (+2 chips) | — | — |

---

## 21. Bus Definition (40-pin, future-proof)

| Pin | Signal | Pin | Signal |
|:---:|--------|:---:|--------|
| 1 | GND | 21 | A0 |
| 2 | GND | 22 | A1 |
| 3 | VCC | 23 | A2 |
| 4 | VCC | 24 | A3 |
| 5 | CLK | 25 | A4 |
| 6 | /RST | 26 | A5 |
| 7 | /RD | 27 | A6 |
| 8 | /WR | 28 | A7 |
| 9 | /NMI | 29 | D0 |
| 10 | /IRQ | 30 | D1 |
| 11 | /SLOT1 | 31 | D2 |
| 12 | /SLOT2 | 32 | D3 |
| 13 | /SLOT3 | 33 | D4 |
| 14 | /SLOT4 | 34 | D5 |
| 15 | PG[4] | 35 | D6 |
| 16 | PG[5] | 36 | D7 |
| 17 | PG[6] | 37 | N/A |
| 18 | PG[7] | 38 | N/A |
| 19 | N/A | 39 | N/A |
| 20 | N/A | 40 | N/A |

Defined: 32 pins. Reserved: 8 pins (N/A) for future use (DMA, HALT, SYNC, etc.)
Same 40-pin IDC connector as RV8 — same ribbon cable, same physical form factor.

---

## 22. Expansion Slots

```
Data page map:
  Page $00-$7F: On-board RAM (32KB)
  Page $80-$8F: SLOT 1 (4KB — RAM/ROM cartridge)
  Page $90-$9F: SLOT 2 (4KB — device)
  Page $A0-$AF: SLOT 3 (4KB — device)
  Page $B0-$BF: SLOT 4 (4KB — device)
  Page $F0-$FF: System I/O (keyboard, screen, SD, UART)
```

Slot devices just need: /SLOTn active + A[7:0] + D[7:0] + /RD + /WR.
No address decode needed on the device — CPU provides pre-decoded /SLOT signals.

---

## 23. RV8 vs RV808 — When to Use Which

### For education: RV8 is better

- Parallel bus = students see address AND data on LEDs simultaneously
- Simpler state machine (2.5 cycles avg) = easier to step through
- 74HC161 counters teach cascading and carry chains
- Pointer auto-increment teaches hardware optimization
- More "textbook" architecture — maps to CS courses
- Debugging is straightforward (every signal has a dedicated wire)

### For real use (single-board computer): RV808 is better

- 23 chips, 17 active pins = compact PCB product
- Harvard fetch = clean code/data separation (safer)
- Page model = natural fit for memory-mapped I/O and expansion
- Fewer wires = cheaper PCB, fewer routing layers
- At 10 MHz, still runs BASIC and games fine
- Expansion via slots is cleaner

### The philosophy:

> **RV8 teaches you how a CPU works. RV808 teaches you how to design one.**

Build RV8 first (breadboard, 12 labs, learn everything).
Then design RV808 as the graduation project — a real engineering exercise
in trade-offs, optimization, and constraints.

---

## 24. Software Compatibility

| Instructions | RV8 | RV808 | Status |
|-------------|:---:|:-----:|--------|
| ALU, branches, shifts, LI, PUSH/POP, JAL/RET, interrupts, skip | ✅ | ✅ | ~58 instructions identical |
| LI pl/ph, LB/SB (ptr)/(ptr+), INC16/DEC16/ADD16 | ✅ | ❌ | Removed (~7 instructions) |
| PAGE imm, LB/SB pg:t0 | ❌ | ✅ | Added (~3 instructions) |

~85% binary compatible. 100% source-portable with mechanical translation:

```
RV8:                         RV808:
LI ph, $12                   PAGE $12
LI pl, $34                   LI t0, $34
LB (ptr)                     LB pg:t0
```
