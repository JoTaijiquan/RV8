# RV8-S — Serial Bus, Microcode, RISC-V ISA

**~12 logic chips. Same ISA as RV8. Bit-serial ALU. Slowest but fewest chips.**

---

## Core Idea

Same RISC-V ISA as RV8, but process data **1 bit at a time** instead of 8 bits parallel. Massively reduces chip count at the cost of speed.

---

## Architecture

```
8-bit registers stored in SHIFT REGISTERS (74HC595)
1-bit ALU (2 gates: XOR + AND = full adder)
Serial data transfer: 8 clocks per byte
Microcode Flash sequences everything (same as RV8)
```

---

## Chip List (~12 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U8 | 74HC595 ×8 | Registers r0-r7 (shift register, serial I/O) |
| U9 | 74HC595 | IR opcode (shift in from ROM) |
| U10 | 74HC595 | IR operand |
| U11 | 74HC74 | 1-bit ALU (FF for carry) + state |
| U12 | 74HC86 | XOR (1 gate = full adder sum, 1 gate = SUB invert) |
| U13 | 74HC08 | AND (1 gate = full adder carry, 1 gate = control) |
| U14-U15 | 74HC595 ×2 | PC (16-bit shift register) |
| U16 | SST39SF010A | Microcode Flash |
| — | AT28C256 | Program ROM |
| — | 62256 | RAM |
| **Total** | **~16 logic + ROM + RAM = 18** | |

Wait — 74HC595 is serial-in, parallel-out. For registers that need both serial shift AND parallel output (to address bus), 595 works. But for serial-in serial-out (ALU chain), we need the serial output pin.

Actually: 74HC595 has:
- Serial input (SER)
- Serial output (QH' — last bit shifts out)
- Parallel outputs (QA-QH)
- Shift clock (SRCLK)
- Latch clock (RCLK)

Perfect! Serial chain: one register's QH' → next register's SER. Or → ALU input.

---

## How 1-bit ALU works:

```
For ADD a0, a0, r2:
  Clock 1: a0.bit0 + r2.bit0 + carry_in → result.bit0, new carry
  Clock 2: a0.bit1 + r2.bit1 + carry → result.bit1, new carry
  ...
  Clock 8: a0.bit7 + r2.bit7 + carry → result.bit7, final carry

Full adder (1 bit):
  SUM = A XOR B XOR Cin        (1 XOR gate from U12)
  Cout = (A AND B) OR (Cin AND (A XOR B))  (needs 2 AND + 1 OR... or use carry FF trick)

Simplified carry: use 74HC74 FF to store carry between bits.
```

---

## Timing:

```
Per instruction:
  Fetch opcode:  8 serial clocks (shift 8 bits from ROM)
  Fetch operand: 8 serial clocks
  Load rs:       8 serial clocks (shift register to ALU)
  Execute:       8 serial clocks (ALU processes bit by bit)
  Store result:  8 serial clocks (shift result into destination)
  Total: ~40 serial clocks per instruction

At 10 MHz serial clock: 10M / 40 = 250K instructions/sec
At 3.5 MHz: ~87K instructions/sec
```

---

## Problem: ROM and RAM are parallel (8-bit)

ROM outputs 8 bits at once. To shift them in serially, need parallel-to-serial conversion:
- Use 74HC165 (parallel-in, serial-out) — +1 chip
- Or: use ROM parallel output → 595 latch (parallel load mode)

74HC595 has NO parallel load. Need 74HC165 for ROM→serial conversion.

**Revised: +1 chip (74HC165) for ROM interface.**

For RAM write: need serial-to-parallel (595 parallel output → RAM data pins). Already have it — 595 outputs are parallel.

For RAM read: need parallel-to-serial (RAM data → shift in). Another 74HC165.

**+2 chips (74HC165 ×2) for ROM and RAM interface.**

---

## Revised Chip List (~15 logic):

| Function | Chips | Count |
|----------|-------|:-----:|
| Registers r0-r7 | 74HC595 ×8 | 8 |
| IR (opcode + operand) | 74HC595 ×2 | 2 |
| PC (16-bit) | 74HC595 ×2 | 2 |
| ALU (1-bit: carry FF + XOR + AND) | 74HC74 + 74HC86 + 74HC08 | 3 |
| ROM/RAM interface (parallel↔serial) | 74HC165 ×2 | 2 |
| Microcode Flash | SST39SF010A | 1 |
| Program ROM | AT28C256 | 1 |
| RAM | 62256 | 1 |
| **Total** | **18 logic + ROM + RAM = 20** | |

Hmm — 18 logic is more than expected. The parallel↔serial conversion adds chips.

**Actually**: if we accept that ROM/RAM interface uses the 595's parallel outputs directly (not serial), we can reduce. The serial part is only for ALU and register-to-register transfers. Memory access uses parallel outputs of the 595 registers.

Revised: ROM data → 595 parallel load... but 595 doesn't have parallel load!

**Use 74HC574 for IR instead** (parallel latch from ROM, then shift out serially via separate 165):

This is getting complex. Let me simplify:

---

## Simplified RV8-S (hybrid serial/parallel):

```
Registers: 74HC595 ×8 (serial ALU chain)
IR: 74HC574 ×2 (parallel latch from ROM — standard)
PC: 74HC161 ×4 (parallel counter — standard, drives ROM address)
ALU: 1-bit serial (74HC74 + 74HC86 + 74HC08)
ROM/RAM: parallel interface (standard)

Serial only for: register ↔ ALU transfers
Parallel for: fetch, memory access, address
```

| Function | Chips | Count |
|----------|-------|:-----:|
| Registers r0-r7 | 74HC595 ×8 | 8 |
| IR | 74HC574 ×2 | 2 |
| PC | 74HC161 ×4 | 4 |
| ALU (1-bit) | 74HC74 + 74HC86 + 74HC08 | 3 |
| Register select | 74HC138 ×1 | 1 |
| Microcode | SST39SF010A | 1 |
| ROM | AT28C256 | 1 |
| RAM | 62256 | 1 |
| **Total** | **19 logic + ROM + RAM = 21** | |

---

## Performance:

```
Fetch: 2 parallel cycles (same as RV8-W: read opcode, read operand)
Execute: 8 serial clocks (ALU processes 1 bit per clock)
Total: 2 + 8 = 10 clocks per ALU instruction

At 10 MHz: 10M / 10 = 1.0M instructions/sec = 1.0 MIPS
At 3.5 MHz: 350K instructions/sec
```

Better than pure serial (250K) because fetch is still parallel!

---

## Comparison (all designs):

| | **RV8** | **RV8-W** | **RV8-S** |
|--|:---:|:---:|:---:|
| Logic chips | 27 | **24** | 19 |
| Total | 29 | **26** | 21 |
| MIPS @ 10 MHz | 2.17 | **5.0** | 1.0 |
| Control | Flash microcode | Instruction=control | Flash microcode |
| ALU | 8-bit parallel | 8-bit parallel | **1-bit serial** |
| Registers | 74HC574 (parallel) | 74HC574 (parallel) | **74HC595 (shift)** |
| ISA | RISC-V reg-reg | RISC-V accumulator | **RISC-V reg-reg** (same as RV8!) |
| BASIC | ✅ fast | ✅ very fast | ✅ slow but works |
| Games (60fps) | ✅ | ✅ | ⚠️ marginal (16K instr/frame) |
| Best for | Flexibility | Speed | **Fewest chips** |

---

## Is 1.0 MIPS enough for games?

```
60 fps × instructions per frame:
  1.0M / 60 = 16,666 instructions per frame

Simple game (Snake): ~500 instructions/frame → ✅ easy
Medium game (Tetris): ~2000 instructions/frame → ✅ fine
Complex game (scrolling): ~10000 instructions/frame → ⚠️ tight
```

**Yes for simple games. Marginal for complex ones.**

---

## Verdict:

RV8-S is the **fewest chips** (19 logic) that can run the full RISC-V ISA. Trade-off is speed (1 MIPS vs 5 MIPS). Good for ultra-minimal builds where chip count matters more than speed.
