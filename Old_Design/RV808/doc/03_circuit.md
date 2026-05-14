# RV808 — Circuit Diagram (Text Schematic)

**23 chips: 21 CPU logic + ROM + RAM**

---

## 1. System Block Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  RV808 CPU BOARD                                             │
│                                                              │
│  ┌────────┐     ┌────────┐     ┌────────┐                  │
│  │ CLOCK  │     │ RESET  │     │  CPU   │                  │
│  │3.5 MHz │     │ BUTTON │     │21 chips│                  │
│  │crystal │     │        │     │        │                  │
│  └───┬────┘     └───┬────┘     └───┬────┘                  │
│      │CLK           │/RST          │                        │
│      ▼              ▼              ▼                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  PC[14:0] ──────────────────────→ ROM A[14:0]        │  │
│  │  ROM D[7:0] ────────────────────→ IR input           │  │
│  │                                                       │  │
│  │  pg ──→ PAGE LATCH ──→ RAM A[14:8]                   │  │
│  │  offset (operand/t0/sp) ──→ RAM A[7:0]              │  │
│  │  D[7:0] ←→ RAM D[7:0]                               │  │
│  │                                                       │  │
│  │  ADDRESS DECODE ──→ /RAM_CE, /IO_CE                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                         │                                    │
│                    40-pin bus                                │
│              (D[7:0], A[7:0], /SLOT1-4, control)           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                    Expansion / I/O
```

---

## 2. Chip List

| U# | Chip | Package | Function |
|:--:|------|:-------:|----------|
| U1 | 74HC161 | DIP-16 | PCL bits 3:0 |
| U2 | 74HC161 | DIP-16 | PCL bits 7:4 |
| U3 | 74HC161 | DIP-16 | PCH bits 11:8 |
| U4 | 74HC161 | DIP-16 | PCH bits 15:12 |
| U5 | 74HC574 | DIP-20 | IR opcode |
| U6 | 74HC574 | DIP-20 | IR operand |
| U7 | 74HC574 | DIP-20 | a0 (accumulator) |
| U8 | 74HC574 | DIP-20 | t0 (temporary/index) |
| U9 | 74HC574 | DIP-20 | sp (stack pointer) |
| U10 | 74HC574 | DIP-20 | pg (page register) |
| U11 | 74HC283 | DIP-16 | ALU adder bits 3:0 |
| U12 | 74HC283 | DIP-16 | ALU adder bits 7:4 |
| U13 | 74HC86 | DIP-14 | XOR (SUB invert + XOR op) |
| U14 | 74HC138 | DIP-16 | Instruction unit decode |
| U15 | 74HC74 | DIP-14 | Flags: Z, C |
| U16 | 74HC74 | DIP-14 | State + N flag + RAM_EXEC |
| U17 | 74HC08 | DIP-14 | AND control logic |
| U18 | 74HC32 | DIP-14 | OR control logic |
| U19 | 74HC245 | DIP-20 | Data bus buffer (external I/O) |
| U20 | 74HC574 | DIP-20 | Page latch (→ RAM A[14:8]) |
| U21 | 74HC138 | DIP-16 | Address decode (RAM/IO/slots) |
| — | AT28C256 | DIP-28 | Program ROM (32KB) |
| — | 62256 | DIP-28 | Data RAM (32KB) |

---

## 3. Program Counter (U1–U4: 74HC161 ×4)

```
U1: PCL[3:0]        U2: PCL[7:4]        U3: PCH[11:8]      U4: PCH[15:12]
┌──────────┐        ┌──────────┐        ┌──────────┐        ┌──────────┐
│ CLK ← clk│        │ CLK ← clk│        │ CLK ← clk│        │ CLK ← clk│
│ /CLR← rst │        │ /CLR← rst │        │ /CLR← rst │        │ /CLR← rst │
│ /LD ← pc_ld       │ /LD ← pc_ld       │ /LD ← pc_ld       │ /LD ← pc_ld
│ ENT ← pc_inc      │ ENT ← U1.TC       │ ENT ← U2.TC       │ ENT ← U3.TC
│ ENP ← pc_inc      │ ENP ← pc_inc      │ ENP ← pc_inc      │ ENP ← pc_inc
│ D0-D3 ← data      │ D0-D3 ← data      │ D0-D3 ← data      │ D0-D3 ← data
│ Q0-Q3 → ROM A0-A3 │ Q0-Q3 → ROM A4-A7 │ Q0-Q3 → ROM A8-A11│ Q0-Q3 →ROM A12-A14
│ TC → U2.ENT       │ TC → U3.ENT       │ TC → U4.ENT       │ TC → (unused)
└──────────┘        └──────────┘        └──────────┘        └──────────┘

pc_inc = state is F0 or F1 (fetch phase)
pc_ld  = branch taken or jump (load new PC value)
data   = branch target from ALU or vector address
```

---

## 4. Instruction Register (U5–U6: 74HC574 ×2)

```
U5: IR Opcode              U6: IR Operand
┌──────────────┐           ┌──────────────┐
│ CLK ← ir0_clk│           │ CLK ← ir1_clk│
│ /OE ← GND    │           │ /OE ← GND    │
│ D0-D7 ← ROM D[7:0]      │ D0-D7 ← ROM D[7:0]
│ Q0-Q7 → decode + control │ Q0-Q7 → ALU B / RAM A[7:0] / branch offset
└──────────────┘           └──────────────┘

ir0_clk = CLK AND (state == F0)
ir1_clk = CLK AND (state == F1)

ROM data output feeds BOTH IR latches (only one clocks at a time).
U6 operand output also drives RAM A[7:0] for pg:imm addressing.
```

---

## 5. Registers (U7–U10: 74HC574 ×4)

```
U7: a0 (accumulator)  U8: t0 (index)       U9: sp (stack ptr)  U10: pg (page)
┌────────────┐        ┌────────────┐        ┌────────────┐        ┌────────────┐
│CLK ← a0_clk│        │CLK ← t0_clk│        │CLK ← sp_clk│        │CLK ← pg_clk│
│/OE ← GND   │        │/OE ← GND   │        │/OE ← GND   │        │/OE ← GND   │
│D[7:0]←alu_r│        │D[7:0]←data  │        │D[7:0]←data  │        │D[7:0]←data  │
│Q[7:0]→ALU A│        │Q[7:0]→RAM A │        │Q[7:0]→RAM A │        │Q[7:0]→U20 D │
│      →data  │        │      →ALU B │        │(+adder for  │        │      →bus   │
└────────────┘        └────────────┘        │ sp+imm)     │        └────────────┘
                                             └────────────┘

a0: always feeds ALU input A, receives ALU result
t0: feeds RAM A[7:0] for pg:t0 mode, also ALU B for register ops
sp: feeds RAM A[7:0] for stack mode (with optional +imm adder)
pg: feeds page latch U20 (and external bus for /PG_WR)
```

---

## 6. ALU (U11–U13)

```
U11: 74HC283 (adder low)     U12: 74HC283 (adder high)
┌──────────────┐             ┌──────────────┐
│ A1-A4 ← a0[3:0]           │ A1-A4 ← a0[7:4]
│ B1-B4 ← alu_b[3:0]       │ B1-B4 ← alu_b[7:4]
│ C0 ← carry_in             │ C0 ← U11.C4
│ S1-S4 → result[3:0]       │ S1-S4 → result[7:4]
│ C4 → U12.C0               │ C4 → carry_out → flag_c
└──────────────┘             └──────────────┘

U13: 74HC86 (XOR ×4)
┌──────────────┐
│ Used for:
│  - B input inversion (SUB: B XOR $FF)
│  - XOR operation (A XOR B)
│  Controlled by alu_op signals from decode
└──────────────┘

ALU input B source (mux via control):
  - ir_operand (immediate instructions)
  - t0 (register ALU ops)
  - $01 (INC), $FF inverted (DEC)
  - $00 (shift operations use different path)
```

---

## 7. Page Latch (U20: 74HC574)

```
U20: Page Latch
┌──────────────┐
│ CLK ← pg_clk │  (same clock as pg register U10)
│ /OE ← GND    │
│ D[7:0] ← pg register output (U10 Q)
│ Q[7:0] → RAM A[14:8] (top 7 bits of RAM address)
└──────────────┘

The page latch holds the high byte of the RAM address.
Updated whenever PAGE instruction executes.
RAM sees: address = {U20.Q[6:0], A[7:0]} = 15-bit (32KB)
```

---

## 8. RAM Address Mux

```
RAM A[7:0] source (selected by addr_src from control):

  addr_src = 00: U6 Q[7:0] (ir_operand) — pg:imm mode
  addr_src = 01: U8 Q[7:0] (t0)         — pg:t0 mode
  addr_src = 10: U9 Q[7:0] (sp)         — stack mode
  addr_src = 11: U9 + U6 (sp + imm)     — sp+imm mode (uses ALU)

For stack mode: page latch forced to $01 (hardwired via U21 decode)
For zero-page: page latch forced to $00

Implementation: U6, U8, U9 outputs go through tri-state or mux to RAM A[7:0]
  - Simplest: use /OE on U6/U8/U9 to select which drives RAM address
  - Or: 74HC157 ×2 mux (but adds 2 chips)
  
Since 574 has /OE, we can tri-state select:
  Only ONE of U6/U8/U9 has /OE=LOW at a time → drives RAM A[7:0]
  Control logic generates: opr_oe_n, t0_oe_n, sp_oe_n
```

---

## 9. Address Decode (U21: 74HC138)

```
U21: 74HC138 — decodes page register top bits for chip select

Inputs:
  A = pg[7] (or page_latch[7])
  B = pg[6]
  C = pg[5]
  G1 = data_access (active during M1/M2 states)
  /G2A = GND
  /G2B = GND

Outputs:
  /Y0 = pages $00-$1F → RAM /CE (on-board RAM)
  /Y1 = pages $20-$3F → RAM /CE (on-board RAM)
  /Y2 = pages $40-$5F → RAM /CE (on-board RAM)
  /Y3 = pages $60-$7F → RAM /CE (on-board RAM)
  /Y4 = pages $80-$9F → /SLOT1 + /SLOT2 (external bus)
  /Y5 = pages $A0-$BF → /SLOT3 + /SLOT4 (external bus)
  /Y6 = pages $C0-$DF → (reserved)
  /Y7 = pages $E0-$FF → /IO (system I/O on external bus)

RAM /CE = /Y0 AND /Y1 AND /Y2 AND /Y3 (active for pages $00-$7F)
  → simplified: RAM /CE = NOT(pg[7]) AND data_access
```

---

## 10. Instruction Decode (U14: 74HC138)

```
U14: 74HC138 — decodes opcode[7:5] into unit select

Inputs:
  A = ir_op[5]
  B = ir_op[6]
  C = ir_op[7]
  G1 = execute_phase (state == EX)
  /G2A = GND
  /G2B = GND

Outputs:
  /Y0 = Unit 0: ALU register
  /Y1 = Unit 1: ALU immediate
  /Y2 = Unit 2: Load/Store
  /Y3 = Unit 3: Branch
  /Y4 = Unit 4: Shift/Unary
  /Y5 = Unit 5: Load Immediate
  /Y6 = Unit 6: Stack/Jump
  /Y7 = Unit 7: System
```

---

## 11. Control Logic (U15–U18)

```
U15: 74HC74 (dual D flip-flop) — FLAGS
┌──────────────┐
│ FF1: Z flag (D←alu_zero, CLK←flags_clk)
│ FF2: C flag (D←alu_carry, CLK←flags_clk)
│ /CLR ← /RST
└──────────────┘

U16: 74HC74 (dual D flip-flop) — STATE + N
┌──────────────┐
│ FF1: N flag (D←alu_result[7], CLK←flags_clk)
│ FF2: state bit / RAM_EXEC / skip_flag (shared)
│ /CLR ← /RST
└──────────────┘

U17: 74HC08 (quad AND)
┌──────────────┐
│ Gate 1: ir0_clk = CLK AND state_F0
│ Gate 2: ir1_clk = CLK AND state_F1
│ Gate 3: ram_ce = NOT(pg[7]) AND data_access
│ Gate 4: (spare)
└──────────────┘

U18: 74HC32 (quad OR)
┌──────────────┐
│ Gate 1: pc_inc = state_F0 OR state_F1
│ Gate 2: data_access = state_M1 OR state_M2
│ Gate 3: (state logic)
│ Gate 4: (control combining)
└──────────────┘
```

---

## 12. Data Bus Buffer (U19: 74HC245)

```
U19: 74HC245 — bidirectional buffer for external I/O bus
┌──────────────┐
│ DIR ← read/write (HIGH=A→B for read, LOW=B→A for write)
│ /OE ← io_active (only enabled for external I/O pages $80+)
│ A[7:0] ← internal data bus
│ B[7:0] ← external D[7:0] bus pins
└──────────────┘

Only active when accessing pages $80-$FF (external devices).
For on-board RAM (pages $00-$7F), U19 is disabled (/OE=HIGH).
```

---

## 13. ROM Connections

```
AT28C256 (32KB ROM)
┌──────────────┐
│ A0-A3  ← U1 Q0-Q3 (PCL[3:0])
│ A4-A7  ← U2 Q0-Q3 (PCL[7:4])
│ A8-A11 ← U3 Q0-Q3 (PCH[11:8])
│ A12-A14← U4 Q0-Q2 (PCH[14:12])
│ D0-D7  → IR input (U5.D, U6.D)
│ /OE    ← GND (always reading)
│ /CE    ← GND (always selected)
│ /WE    ← VCC (never writing)
└──────────────┘

ROM is DIRECTLY wired to PC. No bus, no mux.
ROM data output goes directly to IR latch inputs.
```

---

## 14. RAM Connections

```
62256 (32KB RAM)
┌──────────────┐
│ A0-A7  ← address mux (operand/t0/sp)
│ A8-A14 ← U20 Q0-Q6 (page latch, 7 bits)
│ D0-D7  ↔ internal data bus
│ /OE    ← /RD (from control)
│ /CE    ← ram_ce (active for pages $00-$7F)
│ /WE    ← /WR (from control)
└──────────────┘
```

---

## 15. Clock + Reset

```
Crystal Oscillator (3.5 MHz / 10 MHz)
┌─────────┐
│ VCC  OUT├──→ CLK rail → all sequential chips
│ GND  NC │
└─────────┘
(100nF decoupling between VCC and GND)

Reset:
VCC ──[10K]──┬──→ /RST → all /CLR pins
             │
RESET btn ───┘
(to GND)     │
            100nF
             │
            GND
```

---

## 16. Power

```
USB 5V ──►[1N5817]──►[100µF]──┬──► +5V rail
                               │
                          [100nF] ×5 (near clock, ROM, RAM, U14, U21)
                               │
                              GND
```

---

## 17. Pin Count Verification

| Chip | Pins | Package | Count |
|------|:----:|---------|:-----:|
| 74HC161 | 16 | DIP-16 | ×4 |
| 74HC574 | 20 | DIP-20 | ×7 |
| 74HC283 | 16 | DIP-16 | ×2 |
| 74HC86 | 14 | DIP-14 | ×1 |
| 74HC138 | 16 | DIP-16 | ×2 |
| 74HC74 | 14 | DIP-14 | ×2 |
| 74HC08 | 14 | DIP-14 | ×1 |
| 74HC32 | 14 | DIP-14 | ×1 |
| 74HC245 | 20 | DIP-20 | ×1 |
| AT28C256 | 28 | DIP-28 | ×1 |
| 62256 | 28 | DIP-28 | ×1 |
| **Total** | | | **23 chips** |

---

## 18. Breadboard Layout

```
Breadboard 1: PC (U1-U4) + ROM
Breadboard 2: IR (U5-U6) + Registers (U7-U10) + Page Latch (U20)
Breadboard 3: ALU (U11-U13) + Control (U14-U18) + Bus Buffer (U19) + Decode (U21) + RAM
```

3 breadboards. Connect with short wires (all on-board, no ribbon cable needed for basic operation).

---

## 19. Signal Summary

| Signal | Source | Destination | Width |
|--------|--------|-------------|:-----:|
| PC[14:0] | U1-U4 Q outputs | ROM A[14:0] | 15 |
| ROM_D[7:0] | ROM data out | U5.D, U6.D (IR) | 8 |
| RAM_A[14:8] | U20 Q[6:0] (page latch) | RAM A[14:8] | 7 |
| RAM_A[7:0] | operand/t0/sp (muxed) | RAM A[7:0] | 8 |
| RAM_D[7:0] | internal data bus | RAM D[7:0] | 8 |
| CLK | Crystal oscillator | All sequential chips | 1 |
| /RST | Reset circuit | All /CLR pins | 1 |
| /RD | Control logic | RAM /OE | 1 |
| /WR | Control logic | RAM /WE | 1 |
| /PG_WR | Control logic | U20 CLK (page latch) | 1 |
| EXT_D[7:0] | U19 B side | External bus | 8 |
| EXT_A[7:0] | operand/t0/sp | External bus | 8 |
| /SLOT1-4 | U21 outputs | External bus | 4 |
| /NMI | External | Control logic | 1 |
| /IRQ | External | Control logic | 1 |

---

## 20. 40-Pin Bus Connector

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
| 15 | PG4 | 35 | D6 |
| 16 | PG5 | 36 | D7 |
| 17 | PG6 | 37 | SYNC |
| 18 | PG7 | 38 | N/A |
| 19 | N/A | 39 | N/A |
| 20 | N/A | 40 | N/A |
