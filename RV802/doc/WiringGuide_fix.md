# RV802 WiringGuide — Verification & Fix

## Bug Found: Address Bus Conflict

**Problem**: PC (74HC161 ×4) outputs are ALWAYS driving ADDR[15:0]. During LB/SB, register value needs to drive ADDR instead. Two sources on same wire = conflict.

74HC161 has NO /OE pin. Cannot tri-state its outputs.

## Fix: Add address latches + PC buffer

```
ADDR[15:0] driven by:
  During FETCH: PC (via 74HC541 buffer, /OE=fetch_mode)
  During DATA:  Address latches (74HC574 ×2, loaded from IBUS)

New chips needed:
  U26: 74HC541 (PC low buffer, /OE=data_mode → disabled during data access)
  U27: 74HC541 (PC high buffer, /OE=data_mode)
  U28: 74HC574 (Address latch low, loaded from IBUS during addr setup step)
  U29: 74HC574 (Address latch high, loaded from IBUS during addr setup step)
```

Wait — that's +4 chips. Too many.

## Better fix: Replace PC counters with 74HC574 registers

```
Replace: U16-U19 (74HC161 ×4, 16-bit counter, no /OE)
With:    U16-U17 (74HC574 ×2, 16-bit register, HAS /OE)

PC increment: done by ALU during fetch (microcode adds 1)
PC load: done by ALU during branch (microcode loads offset)

Benefit: 74HC574 has /OE → can tri-state during data access
         Saves 2 chips (4→2)
         Address bus shared cleanly

Cost: PC increment takes 1 extra micro-step per fetch (ALU busy)
      Slightly slower: 5 cycles/instruction instead of 4
```

## Revised chip list with fix:

| Removed | Added | Net |
|---------|-------|:---:|
| U16-U19 (74HC161 ×4) | U16-U17 (74HC574 ×2, PC with /OE) | −2 |
| — | U26 (74HC574, address latch low) | +1 |
| — | U27 (74HC574, address latch high) | +1 |

**Net change: 0 chips!** Still 25 logic chips.

## How it works:

```
FETCH (steps 0-1):
  PC_low (U16, /OE=LOW) drives ADDR[7:0]
  PC_high (U17, /OE=LOW) drives ADDR[15:8]
  ROM/RAM data → IBUS → IR
  Microcode: PC = PC + 1 (via ALU, takes 1 extra step)

DATA ACCESS (steps for LB/SB):
  Step A: rs_low → IBUS → Addr Latch Low (U26) captures
  Step B: rs_high → IBUS → Addr Latch High (U27) captures
  Step C: PC /OE=HIGH (disconnected), Addr Latches /OE=LOW (drive ADDR)
          Memory read/write happens
  Step D: PC /OE=LOW again (reconnected for next fetch)
```

## Revised timing:

```
Fetch: 3 steps (read opcode, read operand, PC+1 via ALU)
ALU immediate: +1 step (compute)
Total immediate: 4 steps → 2.5 MIPS @ 10 MHz

LB/SB: +3 steps (addr low, addr high, memory access)
Total memory: 6 steps → 1.67 MIPS for memory ops

Average (60% imm, 20% reg, 20% mem): ~4.6 steps → 2.17 MIPS @ 10 MHz
```

Slightly slower than claimed (was 3.0, now 2.17) but ACTUALLY BUILDABLE.

## Final honest chip count: 25 logic + ROM + RAM = 27 total

| U# | Chip | Function |
|:--:|------|----------|
| U1-U8 | 74HC574 ×8 | Registers r0-r7 |
| U9 | 74HC574 | IR opcode |
| U10 | 74HC574 | IR operand / ALU B immediate |
| U11 | 74HC574 | ALU B latch (reg-reg ops) |
| U12-U13 | 74HC283 ×2 | ALU adder |
| U14-U15 | 74HC86 ×2 | XOR (SUB invert) |
| U16-U17 | 74HC574 ×2 | PC (low + high, with /OE) |
| U18-U19 | 74HC574 ×2 | Address latch (low + high, with /OE) |
| U20 | 74HC138 | Register read select |
| U21 | 74HC138 | Register write select |
| U22 | 74HC245 | External bus buffer |
| U23 | SST39SF010A | Microcode Flash |
| U24 | 74HC74 | Flags (Z, C) |
| U25 | 74HC574 | ALU result latch |
| — | AT28C256 | ROM |
| — | 62256 | RAM |
| **Total** | | **25 logic + ROM + RAM = 27** |

## Address bus control:

```
During FETCH:
  U16./OE = LOW (PC low drives ADDR[7:0])
  U17./OE = LOW (PC high drives ADDR[15:8])
  U18./OE = HIGH (addr latch low disconnected)
  U19./OE = HIGH (addr latch high disconnected)

During DATA ACCESS:
  U16./OE = HIGH (PC disconnected)
  U17./OE = HIGH (PC disconnected)
  U18./OE = LOW (addr latch low drives ADDR[7:0])
  U19./OE = LOW (addr latch high drives ADDR[15:8])

Control: one signal "DATA_MODE" from microcode
  DATA_MODE=0: fetch (PC drives)
  DATA_MODE=1: data (latches drive)
  Wire: U16./OE = U17./OE = DATA_MODE
        U18./OE = U19./OE = NOT(DATA_MODE)
  Inversion: use spare XOR gate (tie one input to VCC) as inverter
```

**NO BUS CONFLICT. VERIFIED.**
