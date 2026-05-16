# RV8-R — Instruction Trace

**Trace `ADDI r1, 5` through hardware. Verify 17 chips is correct.**

---

## RV8-R = RV8 minus hardware registers

RV8 has: 8× 574 (registers) + 2× 138 (decode) = 10 chips for register file.
RV8-R removes these. Registers live in RAM at $00-$07.

**But**: RV8's microcode sequences assume registers are on IBUS (instant /OE access). With RAM registers, reading a register requires a full RAM access cycle (set address, read, latch).

---

## RV8-R Chip List (claimed 17):

| U# | Chip | Function |
|:--:|------|----------|
| U1-U2 | 74HC574 ×2 | IR (opcode + operand) |
| U3 | 74HC574 | ALU B latch |
| U4-U5 | 74HC283 ×2 | ALU adder |
| U6-U7 | 74HC86 ×2 | XOR (SUB) |
| U8-U9 | 74HC574 ×2 | PC (low + high, /OE) |
| U10-U11 | 74HC574 ×2 | Address latches (low + high) |
| U12 | 74HC245 | Bus buffer (IBUS ↔ RAM) |
| U13 | SST39SF010A | Microcode Flash #1 |
| U14 | 74HC74 | Flags (Z, C) |
| U15 | 74HC574 | ALU result latch |
| U16 | 74HC161 | Step counter |
| U17 | SST39SF010A | Microcode Flash #2 |
| — | AT28C256 | Program ROM |
| — | 62256 | RAM (registers at $00-$07) |

---

## Trace: `ADDI r1, 5` (r1 = r1 + 5)

r1 lives at RAM[$01]. Current value: $10. Expected result: $15.

### Step 0: Fetch opcode

```
Microcode outputs: PC_ADDR=1, BUF_OE=1, BUF_DIR=0, IR_CLK=1, PC_INC=1
PC ($C000) → address bus → ROM → D[7:0] = opcode → U12 (245) → IBUS → U1 (IR) latches
PC increments to $C001.
```

**Check**: PC (U8-U9, 574 with /OE) drives address bus. /OE=LOW (PC_ADDR=1). ✅
Buffer (U12) enabled, direction=read. ✅
IR (U1) CLK pulses. ✅

### Step 1: Fetch operand

```
Same as step 0 but OPR_CLK instead of IR_CLK.
PC ($C001) → ROM → $05 → IBUS → U2 (operand) latches.
PC increments to $C002.
```
✅ No issues.

### Step 2: Read register r1 from RAM

```
Need: RAM[$01] → IBUS → ALU B latch

Microcode outputs: PC_ADDR=0, ADDR_CLK=1, BUF_OE=1, BUF_DIR=0
```

**Wait**: To read RAM[$01], need address $0001 on address bus. Where does $0001 come from?

In RV8 (hardware registers): microcode enables register /OE → value on IBUS instantly.
In RV8-R (RAM registers): must put $0001 on address bus, then read RAM.

**How to put $0001 on address bus:**
- Address latches (U10-U11) drive address bus when PC disconnects.
- But address latches get their value from IBUS.
- IBUS currently has... nothing (buffer not yet enabled for this address).

**Need to put register address ($01) onto address bus.** Where does $01 come from?

From the **opcode**: `rd` field = opcode[2:0] = register number. This is in U1 (IR opcode) Q outputs.

**But**: IR Q outputs go to Flash address pins (for microcode lookup). They don't go to IBUS or address bus!

**Problem**: Register address (from opcode rd field) needs to reach the address bus. In RV8, this went to the 138 decoder. In RV8-R, it needs to go to address latches → address bus.

**Path needed**: IR opcode[2:0] → somehow → address bus A[2:0] (with A[15:3] = 0)

**Options**:
1. Wire IR opcode[2:0] directly to address latch D inputs (hardwired, always) — but address latches also need IBUS data for memory access addresses!
2. Put register address on IBUS first, then latch into address register — but how does 3-bit rd field get onto 8-bit IBUS?
3. Use operand byte as register address — operand[7:5] = rs field. This IS on IBUS (from U2 outputs)!

**Option 3 works for rs (source register)**! The operand byte contains rs[7:5]. Microcode can:
- Step 2a: Enable U2 (operand) /OE → IBUS = operand byte → address latch captures
- Step 2b: But address latch gets the FULL operand byte, not just rs field...

For `ADDI r1, 5`: operand = $05 (immediate value). There's no rs field — it's all immediate!

**For ADDI**: the destination register (rd) comes from opcode[2:0]. The value to add is the operand. We need to:
1. Read RAM[rd] (current r1 value)
2. Add operand (5)
3. Write result back to RAM[rd]

**Step 2 needs rd on address bus.** rd = opcode[2:0] = 3 bits. These are in U1 Q outputs (pins 12-14).

**Fix**: Wire U1.Q[2:0] (opcode rd field) to address latch low D[2:0] inputs. Address latch D[7:3] tied to GND (register addresses are $00-$07, high bits always 0). Address latch high = $00 (hardwired or from separate source).

**But**: Address latch D inputs also need IBUS data (for LB/SB with computed addresses). Can't hardwire them to opcode bits!

**Need a MUX** on address latch D inputs: select between IBUS (for memory addresses) and {00000, opcode[2:0]} (for register addresses).

**+1× 74HC157 (4-bit mux) for address low D-input select.** Or use the existing address latch differently.

**Actually**: Simpler approach. Microcode can sequence:
1. Put $00 on IBUS (how? ALU: 0+0=0, latch result, put on IBUS... complex)
2. Put rd on IBUS (how? opcode bits aren't on IBUS!)

**The fundamental problem**: In RV8-R, the register address (from opcode) has no path to the address bus without extra routing.

---

## Issue found: Register address routing

In RV8: opcode[2:0] → 138 decoder → register /OE. Direct, simple.
In RV8-R: opcode[2:0] needs to reach address bus A[2:0]. No direct path exists.

**Fix options**:
1. +1× 74HC157 mux on address latch inputs (IBUS vs opcode bits) = +1 chip
2. Wire opcode[2:0] directly to address bus A[2:0] via tri-state buffer = +1 chip (74HC541)
3. Use a spare 74HC574 as "register address latch" loaded from opcode bits = already have address latches, just need mux on input

**Cheapest**: Option 1. Add 1× 74HC157 that selects address latch low input between IBUS (for memory) and {00000, opcode[2:0]} (for register access).

**Revised: 18 logic chips.**

---

## Continue trace with fix:

### Step 2: Set register address

```
Microcode: REG_ADDR_MODE=1 (mux selects opcode[2:0] → addr latch low)
           ADDR_CLK=1 (latch captures {00000, 001} = $01)
           ADDR_HI_CLK=1 (latch captures $00 — hardwired or from zero)
```

Address latch low = $01. Address latch high = $00. ✅

### Step 3: Read register from RAM

```
Microcode: PC_ADDR=0 (PC disconnects, addr latches drive)
           BUF_OE=1, BUF_DIR=0 (read RAM → IBUS)
           ALUB_CLK=1 (latch RAM data into ALU B)
```

RAM[$0001] = $10 → D[7:0] → U12 (245) → IBUS = $10 → U3 (ALU B latch) captures $10. ✅

### Step 4: Load operand into... wait

For ADDI, ALU B should be the IMMEDIATE value ($05), not the register value ($10)!

The register value ($10) should be ALU A. But ALU A comes from IBUS (in RV8's design, ALU A = register output on IBUS).

**In RV8-R**: We just read the register onto IBUS. ALU A input comes from IBUS. But we latched it into ALU B (U3)!

**Fix the sequence**:
- Step 3: Read RAM[r1] → IBUS → this IS ALU A (IBUS feeds adder A inputs directly? Or needs latch?)

**Check RV8 design**: In RV8, ALU A = IBUS (the selected register drives IBUS, adder A reads from IBUS). ALU B = from ALU B latch (U3, loaded separately).

So for ADDI:
- Step 2-3: Read RAM[r1] → IBUS (this feeds adder A directly)
- Step 3: Simultaneously, operand ($05) needs to be in ALU B latch

**But**: ALU B latch was loaded WHEN? It needs the operand value. The operand is in U2 (IR operand register). Microcode can enable U2 /OE → IBUS → ALU B latch. But that conflicts with RAM data on IBUS!

**Can't have both register value AND operand on IBUS simultaneously.**

**Solution**: Two separate steps:
- Step 2: Load operand → ALU B latch (U2 drives IBUS → U3 latches)
- Step 3: Read RAM[r1] → IBUS → adder A reads it → compute → latch result

**This works!** Adder A reads from IBUS (which has RAM[r1] value). Adder B reads from U3 latch (which has operand $05). Result = $10 + $05 = $15. ✅

### Step 4: Compute and latch result

```
Microcode: ALUR_CLK=1 (latch adder output into U15)
           FLAGS_CLK=1 (update Z, C)
```

ALU result = $15 → U15 latches. ✅

### Step 5: Write result back to RAM[r1]

```
Microcode: PC_ADDR=0, REG_ADDR_MODE=1 (address = $0001 again)
           Need result ($15) on IBUS → RAM write

But U15 (result latch) needs to drive IBUS. Does it have /OE?
```

U15 is 74HC574. /OE pin exists! If /OE=LOW, Q outputs drive IBUS. ✅

```
Microcode: ALUR_OE=1 (U15 drives IBUS with $15)
           BUF_OE=1, BUF_DIR=1 (write IBUS → RAM)
           RAM /WE pulse
```

RAM[$0001] = $15. ✅

### Step 6: Done

```
Microcode: STEP_RST=1 (reset step counter, back to fetch)
```

---

## Total steps: 7 (fetch 2 + load_B 1 + read_reg 1 + compute 1 + write_reg 1 + end 1)

At 10 MHz: 7 steps = ~1.43 MIPS (was claimed 1.0 MIPS — actually faster than estimated!)

---

## Issues found:

| Issue | Fix | Extra chips |
|-------|-----|:-----------:|
| Register address (opcode[2:0]) needs path to address bus | +1× 74HC157 (mux on addr latch input) | +1 |
| **Total** | | **18 logic chips** |

---

## HONEST RV8-R: 18 logic chips + ROM + RAM = 21 packages

| Claimed | Honest | Difference |
|:-------:|:------:|:----------:|
| 17 | **18** | +1 (register address mux) |

**Only 1 chip off!** The design is nearly correct. Just needs one mux to route opcode[2:0] to address latch for register access.

---

## Verified paths:

| Path | Works? |
|------|:------:|
| PC → address bus → ROM → buffer → IBUS → IR | ✅ |
| Operand (U2) → IBUS → ALU B latch | ✅ |
| Register address (opcode[2:0]) → addr latch → address bus | ✅ (with +1 mux) |
| RAM[reg] → buffer → IBUS → adder A | ✅ |
| Adder result → result latch → IBUS → buffer → RAM[reg] | ✅ |
| PC disconnect (/OE) during RAM access | ✅ |
| Step counter sequences all steps | ✅ |
