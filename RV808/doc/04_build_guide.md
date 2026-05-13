# RV808 — Step-by-Step Build Guide

Build the RV808 CPU across 8 labs on 3 breadboards. Each lab adds chips, test before moving on.

---

## Build Order

```
Lab 1: Clock + Reset               (oscillator)  → square wave on scope
Lab 2: ROM + PC                    (5 chips)     → fetches bytes from ROM
Lab 3: Instruction Register        (2 chips)     → latches opcode + operand
Lab 4: Registers + Page Latch      (5 chips)     → a0, t0, sp, pg + page latch
Lab 5: ALU                         (3 chips)     → ADD/SUB/AND/OR/XOR/shifts
Lab 6: RAM + Address Decode        (3 chips)     → page:offset data access
Lab 7: Control Logic               (5 chips)     → CPU runs programs!
Lab 8: Expansion Bus + I/O         (wiring)      → connect external devices
                                   ─────────
                                    23 chips total
```

---

## Lab 1: Clock + Reset

**Components**: Crystal oscillator (3.5 MHz), pushbutton, 10K, 100nF, LED

**Build**: Wire oscillator → CLK rail. Build /RST with pull-up + debounce.

**Test**: Scope shows 3.5 MHz. /RST clean on press/release.

---

## Lab 2: ROM + PC (U1–U4 + ROM)

**Chips**: 74HC161 ×4 + AT28C256

**Build**: Cascade four 161s (TC→ENT carry chain). Wire PC outputs directly to ROM address pins. ROM data output goes to IR input (next lab).

**Test**: Pre-program ROM with pattern ($AA, $55, $AA...). LEDs on ROM data show alternating pattern as PC counts.

---

## Lab 3: Instruction Register (U5–U6)

**Chips**: 74HC574 ×2

**Build**: ROM D[7:0] → U5.D and U6.D. Gate CLK with state logic: U5 latches on F0, U6 latches on F1.

**Test**: Single-step. U5 shows opcode, U6 shows operand from ROM.

---

## Lab 4: Registers + Page Latch (U7–U10, U20)

**Chips**: 74HC574 ×5

**Build**: Wire a0 (U7) input from ALU output. Wire t0/sp/pg from data bus. Wire pg (U10) output to page latch (U20). Page latch output → RAM A[14:8].

**Test**: Manually clock registers, verify data latches correctly.

---

## Lab 5: ALU (U11–U13)

**Chips**: 74HC283 ×2 + 74HC86

**Build**: a0 → adder A inputs. Operand/t0 → XOR → adder B inputs. Carry chain U11.C4 → U12.C0. Result → a0 input.

**Test**: Set a0=5, operand=3 manually. Verify sum=8 on LEDs.

---

## Lab 6: RAM + Address Decode (U20, U21 + 62256)

**Chips**: 74HC138 + 62256 (page latch U20 already placed in Lab 4)

**Build**: Page latch Q[6:0] → RAM A[14:8]. Address mux (operand/t0/sp) → RAM A[7:0]. U21 decodes page[7:5] for RAM /CE vs I/O.

**Test**: Write byte to RAM via pg:imm, read it back. Verify round-trip.

---

## Lab 7: Control Logic (U14–U18, U19)

**Chips**: 74HC138 + 74HC74 ×2 + 74HC08 + 74HC32 + 74HC245

**Build**: U14 decodes opcode[7:5] into unit select. U15-U16 hold flags + state. U17-U18 generate control signals (ir_clk, pc_inc, data_access). U19 buffers external bus.

**Test**: Load ROM with: `LI a0,$42; ADDI $08; SB zp:$00; HLT`. Run. Verify RAM[$0000] = $4A.

---

## Lab 8: Expansion Bus + I/O (wiring)

**Build**: Connect 40-pin bus header. Wire /SLOT1-4 from U21. Wire D[7:0] and A[7:0] to bus. Add pull-ups on /NMI, /IRQ.

**Test**: Plug in I/O device (LED board on slot). Write to slot page, verify LEDs respond.

**You now have**: Complete RV808 computer with expansion capability!

---

## Test Programs

### Test 1: Load + Add (Lab 7)

```
$0000: A0 42    ; LI a0, $42
$0002: 20 08    ; ADDI $08
$0004: E1 00    ; HLT
; Result: a0 = $4A
```

### Test 2: Store + Load (Lab 7)

```
$0000: A0 99    ; LI a0, $99
$0002: A3 00    ; PAGE $00
$0004: 44 10    ; SB pg:$10
$0006: A0 00    ; LI a0, $00
$0008: 40 10    ; LB pg:$10
$000A: E1 00    ; HLT
; Result: a0 = $99
```

### Test 3: Loop (Lab 7)

```
$0000: A0 00    ; LI a0, $00
$0002: 84 00    ; INC
$0004: 22 05    ; CMPI $05
$0006: 61 FA    ; BNE -6 (back to INC)
$0008: E1 00    ; HLT
; Result: a0 = $05
```

### Test 4: Subroutine (Lab 7)

```
$0000: A2 FF    ; LI sp, $FF
$0002: A3 00    ; PAGE $00
$0004: C4 20    ; JAL $20 (call subroutine at $0020)
$0006: E1 00    ; HLT
; ...
$0020: A0 77    ; LI a0, $77
$0022: C5 00    ; RET
; Result: a0 = $77, PC at HLT
```

---

## Tips

- Wire power (VCC/GND) to every chip FIRST
- Test each lab before moving to the next
- Use colored wires: red=VCC, black=GND, yellow=address, blue=data, green=control
- ROM is directly wired to PC — no bus contention, simplest part
- Single-step via Trainer board for debugging
- Keep wires short, especially near clock and ROM
