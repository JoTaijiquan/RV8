# RV801 — Ultra-Minimal Variant Specification

**Project**: RV801 (RV8 bit-serial variant)  
**Version**: 1.0  
**Date**: 2026-05-11  
**Relationship**: Same ISA as RV8, different microarchitecture

---

## Overview

RV801 is an ultra-minimal implementation of the RV8 ISA using **bit-serial ALU** and **registers in RAM**. Same programs run on both RV8 and RV801 — just slower on RV801.

Two sub-variants:
- **RV801-A**: 8 chips, uses EEPROM for microcode (needs programmer)
- **RV801-B**: 9 chips, fully hardwired (no programmer needed)

---

## Comparison: RV8 vs RV801-A vs RV801-B

| | RV8 (fast) | RV801-A (EEPROM) | RV801-B (hardwired) |
|--|---|---|---|
| CPU chips | 20 | **8** | **9** |
| System chips | 24 | **11** | **12** |
| Gates | ~873 | ~300 | ~340 |
| Speed | ~1.5M instr/s | ~175K instr/s | ~175K instr/s |
| ALU | 8-bit parallel | 1-bit serial | 1-bit serial |
| Registers | Hardware (74HC574) | In RAM | In RAM |
| Control | Direct-encoded FSM | **EEPROM microcode** | **74HC logic (hardwired)** |
| Needs programmer | No | **Yes** | **No** |
| Cost (CPU card) | ~$45 | ~$15 | ~$13 |
| Breadboards | 3 | 1 | 1 |
| Build time | 4-5 weeks | 1-2 weeks | 1-2 weeks |
| Best for | Full computer, games | Schools with programmer | Anyone, anywhere |

---

## RV801 Architecture

```
┌─────────────────────────────────────────────┐
│  RV801 (8 chips)                            │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ PC low   │  │ PC high  │  │ Accum    │  │
│  │ 74HC161  │  │ 74HC161  │  │ 74HC595  │  │
│  │ (4-bit)  │  │ (4-bit)  │  │ (shift)  │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│                                             │
│  ┌──────────┐  ┌──────────┐                │
│  │ ALU      │  │ Flags    │                │
│  │ 74HC153  │  │ 74HC74   │                │
│  │ (1-bit)  │  │ (C + Z)  │                │
│  └──────────┘  └──────────┘                │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ State    │  │ Microcode│  │ Bus buf  │  │
│  │ 74HC161  │  │ AT28C16  │  │ 74HC245  │  │
│  │ (counter)│  │ (EEPROM) │  │          │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────┘
```

---

## Chip List

### RV801-A (8 chips, with EEPROM)

| # | Chip | Function |
|---|------|----------|
| U1 | 74HC161 | PC low 8 bits (cascaded counter) |
| U2 | 74HC161 | PC high 8 bits + state counter (shared) |
| U3 | 74HC595 | Accumulator (8-bit shift register) |
| U4 | 74HC153 | 1-bit ALU (4:1 mux: ADD/AND/OR/XOR) |
| U5 | 74HC74 | Flags (Carry + Zero) + NMI latch |
| U6 | 74HC161 | Micro-step counter (counts 0-15 for bit-serial ops) |
| U7 | AT28C16 | Microcode ROM (2K×8, controls all sequencing) |
| U8 | 74HC245 | Data bus buffer (bidirectional) |

### RV801-B (9 chips, no EEPROM)

| # | Chip | Function |
|---|------|----------|
| U1 | 74HC161 | PC low 8 bits (cascaded counter) |
| U2 | 74HC161 | PC high 8 bits (cascaded) |
| U3 | 74HC595 | Accumulator (8-bit shift register) |
| U4 | 74HC153 | 1-bit ALU (4:1 mux: ADD/AND/OR/XOR) |
| U5 | 74HC74 | Flags (Carry + Zero) + NMI latch |
| U6 | 74HC161 | Phase counter (2-bit) + bit counter (3-bit) |
| U7 | 74HC138 | Phase decode (FETCH/EXEC/WRITE select) |
| U8 | 74HC00 | Signal generation (NAND gates for control) |
| U9 | 74HC245 | Data bus buffer (bidirectional) |

---

## How Bit-Serial ALU Works

Instead of 8 parallel adder bits, process 1 bit per clock:

```
Clock 1: bit 0 of A + bit 0 of B → result bit 0, carry out
Clock 2: bit 1 of A + bit 1 of B + carry → result bit 1, carry out
...
Clock 8: bit 7 of A + bit 7 of B + carry → result bit 7, carry out (final)
```

The 74HC595 shift register holds the accumulator. Each clock, one bit shifts through the 74HC153 ALU mux, which selects ADD/AND/OR/XOR based on microcode output.

**8 clocks per ALU operation** instead of 1. But saves 2 chips (no 74HC283 adders needed).

---

## Registers in RAM

| RAM address | Register | Purpose |
|-------------|----------|---------|
| 0x00 | sp | Stack pointer |
| 0x01 | a0 | Accumulator (shadow — shift reg is primary) |
| 0x02 | pl | Pointer low |
| 0x03 | ph | Pointer high |
| 0x04 | t0 | Temporary |
| 0x05 | pg | Page register |
| 0x06-0x07 | c0-c3 | Constant values (0, 1, FF, 80) |

Microcode reads/writes these RAM locations to "access registers." No hardware register file needed.

---

## Microcode ROM Layout

ROM address: `{opcode[7:4], micro_step[3:0]}` = 8 bits → 256 entries  
ROM data: 8 control signals

| Bit | Signal | Controls |
|-----|--------|----------|
| 0 | shift_in | Shift data into accumulator |
| 1 | alu_op0 | ALU operation select |
| 2 | alu_op1 | ALU operation select |
| 3 | mem_rd | Read from memory |
| 4 | mem_wr | Write to memory |
| 5 | pc_inc | Increment PC |
| 6 | addr_src | 0=PC, 1=register-address |
| 7 | done | Instruction complete, reset micro-step |

---

## Performance (with optimized microcode/sequencing)

| Operation | Micro-steps | Time @ 3.5 MHz |
|-----------|:-----------:|:--------------:|
| Fetch (2 bytes) | 2 | 0.6 µs |
| ALU (8-bit serial) | 8 | 2.3 µs |
| Memory load | 2 | 0.6 µs |
| Simple instruction (MOV, NOP) | 4 | 1.1 µs |
| ALU instruction (ADD, SUB) | 12 | 3.4 µs |
| Memory instruction (LB, SB) | 6 | 1.7 µs |
| **Average instructions/sec** | | **~175K** |
| **BASIC lines/sec** | | **~50** |

---

## ISA Compatibility

| Feature | RV8 | RV801 |
|---------|:---:|:-----:|
| Same opcodes | ✅ | ✅ |
| Same instruction encoding | ✅ | ✅ |
| Same programs (binary compatible) | ✅ | ✅ |
| Constant generator | Hardware | Software (values in RAM) |
| Conditional skip | Hardware | Microcode (skip next fetch) |
| Fetch/execute overlap | Yes | No |
| All 68 instructions | ✅ | ✅ |

Programs compiled for RV8 run unmodified on RV801. Just slower.

---

## Complete System

### RV801-A (11 chips total)

| # | Chip | Function | Cost |
|---|------|----------|------|
| U1-U8 | CPU (above) | Processor | $8 |
| U9 | AT28C256 | Program ROM (32KB) | $4 |
| U10 | 62256 | RAM (32KB) | $3 |
| U11 | 74HC138 | Address decode | $0.50 |
| | | **Total** | **~$15.50** |

### RV801-B (12 chips total)

| # | Chip | Function | Cost |
|---|------|----------|------|
| U1-U9 | CPU (above) | Processor | $6 |
| U10 | AT28C256 | Program ROM (32KB) | $4 |
| U11 | 62256 | RAM (32KB) | $3 |
| U12 | 74HC138 | Address decode | $0.50 |
| | | **Total** | **~$13.50** |

---

## Use Cases

| Use case | RV801 suitable? |
|----------|:---------------:|
| Learning CPU architecture | ✅ Best (simplest build) |
| Running BASIC (simple programs) | ⚠️ Slow but works (~30 lines/sec) |
| Games | ❌ Too slow for real-time |
| First student project | ✅ Perfect (1 breadboard, 1-2 weeks) |
| Upgrade path to RV8 | ✅ Same programs, just swap CPU card |

---

## Student Progression

```
RV801-B (9 chips, $13, no programmer needed)
  OR
RV801-A (8 chips, $15, needs EEPROM programmer)
  "I built a CPU that runs programs!"
       ↓ (same ROM, same programs)
RV8 (20 chips, $45, 3 breadboards)
  "Now it's fast enough for games!"
       ↓ (add peripheral board)
Full Computer (video, sound, keyboard)
  "I built a real computer!"
```

---

*Same ISA. Same programs. Same ROM. Three implementations. Student picks based on skill level and available tools.*
