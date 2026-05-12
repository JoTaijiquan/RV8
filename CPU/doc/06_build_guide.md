# RV8 — Step-by-Step Build Guide

Build the RV8 CPU module-by-module. Each step adds chips, and you test before moving on.

**Prerequisites**: You know 74HC logic, breadboards, and basic digital design.

---

## Build Order

```
Step 1: Clock + Reset               (2 chips)   → square wave on scope
Step 2: Program Counter              (4 chips)   → counts addresses
Step 3: ROM + bus                    (3 chips)   → fetches bytes
Step 4: Instruction Register         (2 chips)   → latches opcode+operand
Step 5: ALU                          (3 chips)   → computes results
Step 6: Registers                    (4 chips)   → stores values
Step 7: Pointer + Address Mux        (4 chips)   → memory addressing
Step 8: Flags + Control Logic        (6 chips)   → full CPU runs
                                    ─────────
                                     27 chips (with RAM + decode)
```

---

## Step 1: Clock + Reset (U25, U24-partial)

**Chips**: 74HC157 (clock mux), pushbutton + RC debounce

**Build**:
- Wire crystal oscillator (3.5 MHz) and step button
- 74HC157 selects between free-run and single-step
- Add /RST button with RC debounce (10K + 100nF)

**Test**:
- Scope on CLK output: clean 3.5 MHz square wave
- Press STEP: one pulse per press
- Press /RST: output goes low

**You now have**: controllable clock + clean reset

---

## Step 2: Program Counter (U1–U4)

**Chips**: 74HC161 ×4

**Build**:
- Cascade four 161s: U1.TC → U2.ENT → U3.ENT → U4.ENT
- Connect CLK, /CLR (from reset)
- Tie ENP and ENT of U1 HIGH (always counting for now)
- Tie /LD HIGH (no loading yet)

**Test**:
- Single-step clock, observe Q outputs with LEDs or scope
- U1 counts 0-F, carries into U2
- After 16 steps, U2 increments
- /RST resets all to 0000

**You now have**: 16-bit counter outputting addresses A[15:0]

---

## Step 3: ROM + Address Decode + Bus Buffer (U9, U11, U8)

**Chips**: AT28C256 (ROM), 74HC138 (decode), 74HC245 (bus buffer)

**Build**:
- Connect PC outputs A[0:14] to ROM address pins
- ROM data pins → 74HC245 → internal data bus
- 74HC138 decodes A[15:13] for chip select
- Tie ROM /OE low (always reading for now)
- Pre-program ROM with test pattern: $C000=AA, $C001=55, $C002=01...

**Test**:
- Single-step: data bus shows ROM contents in sequence
- Step 1: D[7:0] = 0xAA
- Step 2: D[7:0] = 0x55
- PC is fetching bytes from ROM!

**You now have**: PC fetches sequential bytes from ROM

---

## Step 4: Instruction Register (U5–U6)

**Chips**: 74HC574 ×2

**Build**:
- U5 (opcode): D inputs from data bus, CLK gated for state F0
- U6 (operand): D inputs from data bus, CLK gated for state F1
- For now, use a simple toggle FF to alternate F0/F1 states
  (or just wire U5.CLK to CLK and U6.CLK to /CLK)

**Test**:
- Program ROM with: $C000=11, $C001=42, $C002=16, $C003=05...
- After 2 clocks: U5 holds 0x11 (opcode), U6 holds 0x42 (operand)
- Next pair: U5=0x16, U6=0x05
- Verify with LEDs on U5 and U6 outputs

**You now have**: CPU fetches 2-byte instructions (opcode + operand)

---

## Step 5: ALU (U13–U15)

**Chips**: 74HC283 ×2 (adder), 74HC86 ×1 (XOR)

**Build**:
- U13 (low nibble) + U14 (high nibble) cascaded: U13.C4 → U14.C0
- A inputs: wire to 8 DIP switches (simulate accumulator)
- B inputs: wire to U6 output (operand from IR)
- XOR gates (U15): between B inputs and SUB control line
  - SUB=0: B passes through (ADD)
  - SUB=1: B inverted, C0=1 (SUB = A + ~B + 1)

**Test**:
- Set switches A=05, operand=03: sum output = 08 ✓
- Set SUB=1: output = 02 (5-3) ✓
- Set A=FF, B=01: output=00, carry=1 ✓
- Try AND/OR/XOR by routing through U15 differently

**You now have**: working 8-bit ALU

---

## Step 6: Registers (U7–U10)

**Chips**: 74HC574 ×4 (a0, t0, sp, pg)

**Build**:
- U7 (a0): D inputs from ALU result, Q outputs feed ALU input A
- U8 (t0): D inputs from data bus
- U9 (sp): D inputs from data bus
- U10 (pg): D inputs from data bus
- Each register CLK gated by write-enable (manual switch for now)

**Test**:
- Load a0 with ALU result: set switches, pulse a0_clk → a0 latches
- Now ALU input A comes from a0 (feedback loop!)
- Load 05 into a0, set operand=03, pulse a0_clk → a0 becomes 08
- Pulse again → a0 becomes 0B (8+3)
- You're computing iteratively!

**You now have**: ALU + registers = datapath

---

## Step 7: Pointer + Address Mux (U11–U12, U16–U17)

**Chips**: 74HC161 ×2 (pointer), 74HC157 ×2 (address mux)

**Build**:
- U11 (pl) + U12 (ph): 8-bit pointer with auto-increment
  - Load from data bus, ENT for increment, carry cascades
- U16-U17 (address mux): selects what drives address bus
  - S=0: PC (fetch from ROM)
  - S=1: pointer (access RAM via ptr)
- Add 62256 RAM, directly on address/data bus

**Test**:
- Load pointer with $2000 (ph=20, pl=00)
- Switch address mux to pointer: address bus shows $2000
- Write a byte to RAM, read it back
- Increment pointer: address becomes $2001
- You can now read/write RAM!

**You now have**: full memory access (ROM + RAM + pointer)

---

## Step 8: Flags + Control Logic (U18–U23)

**Chips**: 74HC138 (unit decode), 74HC74 ×2 (flags), 74HC08 (AND), 74HC32 (OR)

**Build**:
- U20-U21: Z, C, N flags latched from ALU outputs
- U18: decodes opcode[7:5] into unit-enable signals
- U22 (AND) + U23 (OR): generate control signals
  - ir0_clk, ir1_clk, pc_inc, mem_rd, mem_wr, reg_we
- Wire state machine: F0 → F1 → EX (→ MEM for load/store)
- Connect everything: control signals drive all previous modules

**Test**:
- Program ROM with: `LI a0, 5` (opcode=$11, operand=$05)
- Reset, step through: fetch opcode, fetch operand, execute
- After execute: a0 = 05 ✓
- Program: `LI a0, 5` / `ADDI 3` → a0 = 08 ✓
- Program: `LI a0, 1` / `ADDI 1` / `BNE -2` → counts up forever ✓
- **CPU is running programs!**

**You now have**: complete RV8 CPU (27 chips)

---

## Verification Milestones

| After Step | You can verify |
|:----------:|---------------|
| 1 | Clock waveform on scope |
| 2 | Address bus counts up (LEDs) |
| 3 | Data bus shows ROM contents |
| 4 | IR holds opcode + operand |
| 5 | ALU computes correct results |
| 6 | Registers accumulate values |
| 7 | Pointer addresses RAM correctly |
| 8 | CPU executes programs autonomously |

---

## Test Programs (for Step 8)

### Test 1: Load immediate
```
$C000: 11 05    ; LI a0, 5
$C002: FF 00    ; HLT
```
Verify: a0 = 05, CPU halts.

### Test 2: Add
```
$C000: 11 05    ; LI a0, 5
$C002: 16 03    ; ADDI 3
$C004: FF 00    ; HLT
```
Verify: a0 = 08.

### Test 3: Loop (count to 10)
```
$C000: 11 00    ; LI a0, 0
$C002: 16 01    ; ADDI 1
$C004: 18 0A    ; CMPI 10
$C006: 31 FA    ; BNE -6 (back to $C002)
$C008: FF 00    ; HLT
```
Verify: a0 = 0A when halted.

### Test 4: Memory write/read
```
$C000: 11 42    ; LI a0, $42
$C002: 13 20    ; LI ph, $20
$C004: 12 00    ; LI pl, $00
$C006: 23 00    ; SB (ptr+)
$C008: 11 00    ; LI a0, 0
$C00A: 49 00    ; DEC16
$C00C: 20 00    ; LB (ptr)
$C00E: FF 00    ; HLT
```
Verify: a0 = $42 (read back what was written).

---

## Tips

- Add 8 LEDs on the data bus — you'll see every byte flow
- Add 8 LEDs on a0 output — watch the accumulator change
- Use single-step mode for debugging, free-run when it works
- If something's wrong, check the state machine first (is it advancing?)
- Keep wires short and color-coded: red=VCC, black=GND, yellow=address, blue=data, green=control
