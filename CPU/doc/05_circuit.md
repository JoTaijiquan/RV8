# RV8 — Circuit Diagram (Text Schematic)

**Minimal 8-bit CPU — Accumulator-based, RISC-inspired**

**23 CPU chips + 4 system chips = 27 total**

---

## 1. System Block Diagram

```
                    +5V
                     │
        ┌────────────┼────────────────────────────────────────┐
        │            │                                        │
   ┌────┴────┐  ┌───┴───┐  ┌────────┐  ┌────────┐  ┌───────┴───┐
   │  CLOCK  │  │ RESET │  │  CPU   │  │ADDRESS │  │   DATA    │
   │ 3.5MHz  │  │BUTTON │  │23 chips│  │ DECODE │  │   BUS     │
   │ +STEP   │  │       │  │        │  │74HC138 │  │  (8-bit)  │
   └────┬────┘  └───┬───┘  └───┬────┘  └───┬────┘  └─────┬─────┘
        │           │          │            │              │
        │    CLK    │ /RST     │ A[15:0]    │ /ROM /RAM    │ D[7:0]
        │           │          │            │ /IO          │
        ▼           ▼          ▼            ▼              ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                    ADDRESS BUS (16-bit)                      │
   └──────┬──────────────────┬───────────────────┬──────────────┘
          │                  │                   │
     ┌────┴────┐       ┌────┴────┐        ┌────┴────┐
     │  ROM    │       │  RAM    │        │  I/O    │
     │AT28C256 │       │ 62256   │        │ DEVICES │
     │ 32KB    │       │ 32KB    │        │         │
     │C000-FFFF│       │0000-7FFF│        │8000-80FF│
     └─────────┘       └─────────┘        └─────────┘
```

---

## 2. Address Decode (U24: 74HC138)

```
U24 (74HC138) — 3-to-8 decoder

Inputs:
  A = A15
  B = A14
  C = A13
  G1 = +5V (always enabled)
  /G2A = GND
  /G2B = GND

Outputs:
  /Y0 = active when A[15:13]=000 → RAM 0x0000-0x1FFF
  /Y1 = active when A[15:13]=001 → RAM 0x2000-0x3FFF
  /Y2 = active when A[15:13]=010 → RAM 0x4000-0x5FFF (slot)
  /Y3 = active when A[15:13]=011 → RAM 0x6000-0x7FFF (slot)
  /Y4 = active when A[15:13]=100 → I/O 0x8000-0x9FFF
  /Y5 = (unused)
  /Y6 = active when A[15:13]=110 → ROM 0xC000-0xDFFF
  /Y7 = active when A[15:13]=111 → ROM 0xE000-0xFFFF

RAM /CE = /Y0 AND /Y1 AND /Y2 AND /Y3 (OR gate combines)
ROM /CE = /Y6 AND /Y7
I/O /CE = /Y4
```

---

## 3. CPU Chip-by-Chip Connections

### Program Counter (U1–U4: 74HC161 ×4)

```
U1: PC[3:0]     U2: PC[7:4]     U3: PC[11:8]    U4: PC[15:12]
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ CLK ← clk│    │ CLK ← clk│    │ CLK ← clk│    │ CLK ← clk│
│ /CLR← rst│    │ /CLR← rst│    │ /CLR← rst│    │ /CLR← rst│
│ /LD ← pc_ld   │ /LD ← pc_ld   │ /LD ← pc_ld   │ /LD ← pc_ld
│ ENT ← pc_inc  │ ENT ← U1.TC   │ ENT ← U2.TC   │ ENT ← U3.TC
│ ENP ← pc_inc  │ ENP ← pc_inc  │ ENP ← pc_inc  │ ENP ← pc_inc
│ D0-D3 ← data  │ D0-D3 ← data  │ D0-D3 ← data  │ D0-D3 ← data
│ Q0-Q3 → A0-A3 │ Q0-Q3 → A4-A7 │ Q0-Q3 → A8-A11│ Q0-Q3 →A12-A15
│ TC → U2.ENT   │ TC → U3.ENT   │ TC → U4.ENT   │ TC → (unused)
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

### Instruction Register (U5–U6: 74HC574 ×2)

```
U5: IR Opcode              U6: IR Operand
┌──────────────┐           ┌──────────────┐
│ CLK ← ir0_clk│           │ CLK ← ir1_clk│
│ /OE ← GND    │           │ /OE ← GND    │
│ D0-D7 ← D[7:0]          │ D0-D7 ← D[7:0]
│ Q0-Q7 → opcode[7:0]     │ Q0-Q7 → operand[7:0]
└──────────────┘           └──────────────┘

ir0_clk = CLK AND (state == F1)   ← gates via U22
ir1_clk = CLK AND (state == EX)   ← gates via U22
```

### Registers (U7–U10: 74HC574 ×4)

```
U7: a0                U8: t0                U9: sp                U10: pg
┌────────────┐        ┌────────────┐        ┌────────────┐        ┌────────────┐
│CLK ← a0_clk│        │CLK ← t0_clk│        │CLK ← sp_clk│        │CLK ← pg_clk│
│/OE ← GND   │        │/OE ← GND   │        │/OE ← GND   │        │/OE ← GND   │
│D[7:0]←alu_r│        │D[7:0]←D[7:0]        │D[7:0]←D[7:0]        │D[7:0]←D[7:0]
│Q[7:0]→a0_bus│        │Q[7:0]→t0_bus│        │Q[7:0]→sp_bus│        │Q[7:0]→pg_bus│
└────────────┘        └────────────┘        └────────────┘        └────────────┘
```

### Pointer (U11–U12: 74HC161 ×2)

```
U11: pl (pointer low)         U12: ph (pointer high)
┌──────────────┐              ┌──────────────┐
│ CLK ← clk    │              │ CLK ← clk    │
│ /CLR ← rst   │              │ /CLR ← rst   │
│ /LD ← pl_ld  │              │ /LD ← ph_ld  │
│ ENT ← ptr_inc│              │ ENT ← U11.TC │ ← carry from pl!
│ ENP ← ptr_inc│              │ ENP ← ptr_inc│
│ D0-D3 ← D[3:0]             │ D0-D3 ← D[3:0]
│ Q0-Q3 → pl[3:0]            │ Q0-Q3 → ph[3:0]
│ TC → U12.ENT │              │ TC → (unused) │
└──────────────┘              └──────────────┘
(Note: 161 is 4-bit. Need 2× per byte for full 8-bit pl/ph.
 Simplified here — actual build uses 2×161 per pointer byte
 or 74HC593 8-bit counter.)
```

### ALU (U13–U15)

```
U13: 74HC283 (adder low)     U14: 74HC283 (adder high)
┌──────────────┐             ┌──────────────┐
│ A1-A4 ← a0[3:0]           │ A1-A4 ← a0[7:4]
│ B1-B4 ← alu_b[3:0]       │ B1-B4 ← alu_b[7:4]
│ C0 ← carry_in             │ C0 ← U13.C4
│ S1-S4 → sum[3:0]          │ S1-S4 → sum[7:4]
│ C4 → U14.C0               │ C4 → carry_out
└──────────────┘             └──────────────┘

U15: 74HC86 (XOR ×4)
┌──────────────┐
│ Used for:                  
│  - B input inversion (SUB: B XOR 0xFF)
│  - XOR operation (A XOR B)
│  Controlled by alu_op signals
└──────────────┘

ALU input B mux (directly from operand byte or register):
  alu_b = (is_immediate) ? operand : reg_read
```

### Address Mux (U16–U17: 74HC157 ×2)

```
U16: Address low byte mux (4:1)    U17: Address high byte mux (4:1)
┌──────────────────┐                ┌──────────────────┐
│ S = addr_sel[0]  │                │ S = addr_sel[0]  │
│ /E = GND         │                │ /E = GND         │
│                  │                │                  │
│ 1A = PC[3:0]    │                │ 1A = PC[11:8]   │
│ 1B = pl[3:0]    │                │ 1B = ph[3:0]    │
│ 2A = PC[7:4]    │                │ 2A = PC[15:12]  │
│ 2B = sp/imm[7:4]│                │ 2B = 0x30/0x00/pg│
│                  │                │                  │
│ Y → A[7:0]      │                │ Y → A[15:8]     │
└──────────────────┘                └──────────────────┘

addr_sel controls which source drives the address bus:
  00 = PC (fetch)
  01 = {ph, pl} (pointer)
  10 = {0x30, sp} or {0x00/pg, imm} (stack/zp/page)
  11 = (vector)
```

### Control Logic (U18–U23)

```
U18: 74HC138 (unit decode)
┌──────────────┐
│ A,B,C ← opcode[7:5] (from U5)
│ /G2A ← execute_phase (from state logic)
│ G1 ← +5V
│ /Y0-/Y7 → unit enable signals
└──────────────┘

U19: 74HC245 (data bus buffer)
┌──────────────┐
│ DIR ← read/write
│ /OE ← bus_enable
│ A[7:0] ↔ internal data
│ B[7:0] ↔ external D[7:0]
└──────────────┘

U20: 74HC74 (dual D flip-flop)
┌──────────────┐
│ FF1: Z flag (D←alu_zero, CLK←flags_clk)
│ FF2: C flag (D←alu_carry, CLK←flags_clk)
│ /CLR ← /RST
└──────────────┘

U21: 74HC74 (dual D flip-flop)
┌──────────────┐
│ FF1: N flag + IE (shared via mux)
│ FF2: state[0] + skip_flag + NMI_edge
│ /CLR ← /RST
└──────────────┘

U22: 74HC08 (quad AND)
┌──────────────┐
│ Gate 1: ir0_clk = CLK AND state_F1
│ Gate 2: ir1_clk = CLK AND state_EX
│ Gate 3: skip_gate = write_enable AND NOT(skip)
│ Gate 4: int_gate = nmi_pend AND NOT(skip)
└──────────────┘

U23: 74HC32 (quad OR)
┌──────────────┐
│ Gate 1: RAM_CE = /Y0 OR /Y1 OR /Y2 OR /Y3
│ Gate 2: ROM_CE = /Y6 OR /Y7
│ Gate 3: state logic combining
│ Gate 4: control signal combining
└──────────────┘
```

---

## 4. Clock Circuit

```
                 3.5MHz
                Crystal Osc
                    │
        ┌───────────┤
        │           │
   ┌────┴────┐  ┌──┴──┐
   │ RUN/STEP│  │     │
   │ Switch  │  │ 74HC│    ┌──────────┐
   │    ○────┼──┤ 157 ├────┤ CPU CLK  │
   │         │  │ MUX │    └──────────┘
   │  STEP   │  │     │
   │ Button──┼──┤     │
   │(debounce)  └─────┘
   └─────────┘
   
Debounce: 74HC00 SR latch + 10K + 100nF
```

---

## 5. Power

```
USB 5V ──►[1N5817]──►[100µF]──┬──► +5V rail
                               │
                          [100nF] ×3 (near clock, ROM, RAM)
                               │
                              GND
```

---

## 6. Signal Summary

| Signal | Source | Destination | Width |
|--------|--------|-------------|:-----:|
| A[15:0] | Addr mux (U16-17) | ROM, RAM, I/O | 16 |
| D[7:0] | Bus buffer (U19) | All chips | 8 |
| CLK | Clock circuit | All sequential chips | 1 |
| /RST | Reset button | All /CLR pins | 1 |
| /RD | Control logic | ROM /OE, RAM /OE | 1 |
| /WR | Control logic | RAM /WE | 1 |
| /NMI | External | U21 (edge detect) | 1 |
| /IRQ | External | Control logic | 1 |
| HALT | Control logic | Clock gate (stops CLK) | 1 |
| SYNC | Control logic | External (new instruction fetch) | 1 |

---

## 7. Pin Count Verification

| Chip | Pins | Package |
|------|:----:|---------|
| 74HC161 ×6 | 16 | DIP-16 |
| 74HC574 ×6 | 20 | DIP-20 |
| 74HC283 ×2 | 16 | DIP-16 |
| 74HC86 ×1 | 14 | DIP-14 |
| 74HC157 ×3 | 16 | DIP-16 |
| 74HC138 ×2 | 16 | DIP-16 |
| 74HC245 ×1 | 20 | DIP-20 |
| 74HC74 ×2 | 14 | DIP-14 |
| 74HC08 ×1 | 14 | DIP-14 |
| 74HC32 ×1 | 14 | DIP-14 |
| AT28C256 ×1 | 28 | DIP-28 |
| 62256 ×1 | 28 | DIP-28 |
| **Total: 27 chips** | | |

---

## 8. Breadboard Layout (suggested)

```
Breadboard 1: PC (U1-U4) + Address Mux (U16-U17) + Decode (U18,U24)
Breadboard 2: Registers (U7-U12) + ALU (U13-U15)
Breadboard 3: IR (U5-U6) + Control (U20-U23) + Bus Buffer (U19)
Breadboard 4: ROM + RAM + Clock + Power
```

4 breadboards, ~$20 in boards. Connect with ribbon cable for address/data buses.

---

## Thai Version — ผังวงจร RV8 CPU (ตารางต่อขาทุกชิป)

---

# รายชื่อชิปทั้งหมด 27 ตัว

| U# | เบอร์ | ชื่อเต็ม | ขา | หน้าที่ |
|:--:|-------|---------|:--:|---------|
| U1 | 74HC161 | 4-Bit Synchronous Binary Counter | 16 | PC bit 3:0 |
| U2 | 74HC161 | 4-Bit Synchronous Binary Counter | 16 | PC bit 7:4 |
| U3 | 74HC161 | 4-Bit Synchronous Binary Counter | 16 | PC bit 11:8 |
| U4 | 74HC161 | 4-Bit Synchronous Binary Counter | 16 | PC bit 15:12 |
| U5 | 74HC574 | Octal D-Type Flip-Flop (3-State) | 20 | IR opcode |
| U6 | 74HC574 | Octal D-Type Flip-Flop (3-State) | 20 | IR operand |
| U7 | 74HC574 | Octal D-Type Flip-Flop (3-State) | 20 | a0 (accumulator) |
| U8 | 74HC574 | Octal D-Type Flip-Flop (3-State) | 20 | t0 (temporary) |
| U9 | 74HC574 | Octal D-Type Flip-Flop (3-State) | 20 | sp (stack pointer) |
| U10 | 74HC574 | Octal D-Type Flip-Flop (3-State) | 20 | pg (page register) |
| U11 | 74HC161 | 4-Bit Synchronous Binary Counter | 16 | pl (pointer low) |
| U12 | 74HC161 | 4-Bit Synchronous Binary Counter | 16 | ph (pointer high) |
| U13 | 74HC283 | 4-Bit Binary Full Adder | 16 | ALU adder bit 3:0 |
| U14 | 74HC283 | 4-Bit Binary Full Adder | 16 | ALU adder bit 7:4 |
| U15 | 74HC86 | Quad 2-Input Exclusive-OR Gate | 14 | XOR (SUB invert + XOR op) |
| U16 | 74HC157 | Quad 2-Input Multiplexer | 16 | Address mux low byte |
| U17 | 74HC157 | Quad 2-Input Multiplexer | 16 | Address mux high byte |
| U18 | 74HC138 | 3-to-8 Line Decoder/Demux | 16 | Instruction unit decode |
| U19 | 74HC245 | Octal Bus Transceiver (3-State) | 20 | Data bus buffer |
| U20 | 74HC74 | Dual D-Type Flip-Flop | 14 | Flags: Z, C |
| U21 | 74HC74 | Dual D-Type Flip-Flop | 14 | Flag N + state |
| U22 | 74HC08 | Quad 2-Input AND Gate | 14 | Control: clock gating |
| U23 | 74HC32 | Quad 2-Input OR Gate | 14 | Control: signal combining |
| U24 | 74HC74 | Dual D-Type Flip-Flop | 14 | NMI edge detect + toggle |
| U25 | 74HC157 | Quad 2-Input Multiplexer | 16 | Clock mux (RUN/STEP) |
| — | AT28C256 | 32K×8 Electrically Erasable PROM | 28 | Program ROM |
| — | 62256 | 32K×8 Static RAM | 28 | Data RAM |

---

# ผังขาของแต่ละชิป (Pinout)

---

## 74HC161 (U1–U4, U11–U12) — DIP-16

```
        ┌───╥───┐
  /CLR ─┤1  ╨ 16├─ VCC
   CLK ─┤2    15├─ TC (carry out)
    D0 ─┤3    14├─ QA (output bit 0)
    D1 ─┤4    13├─ QB (output bit 1)
    D2 ─┤5    12├─ QC (output bit 2)
    D3 ─┤6    11├─ QD (output bit 3)
   ENP ─┤7    10├─ ENT
   GND ─┤8     9├─ /LD
        └───────┘
```

## 74HC574 (U5–U10) — DIP-20

```
        ┌───╥───┐
   /OE ─┤1  ╨ 20├─ VCC
    D0 ─┤2    19├─ Q7
    D1 ─┤3    18├─ Q6
    D2 ─┤4    17├─ Q5
    D3 ─┤5    16├─ Q4
    D4 ─┤6    15├─ Q3
    D5 ─┤7    14├─ Q2
    D6 ─┤8    13├─ Q1
    D7 ─┤9    12├─ Q0
   GND ─┤10   11├─ CLK
        └───────┘
```

## 74HC283 (U13–U14) — DIP-16

```
        ┌───╥───┐
    S2 ─┤1  ╨ 16├─ VCC
    B2 ─┤2    15├─ B3
    A2 ─┤3    14├─ A3
    S1 ─┤4    13├─ S3
    A1 ─┤5    12├─ A4
    B1 ─┤6    11├─ B4
    C0 ─┤7    10├─ S4
   GND ─┤8     9├─ C4
        └───────┘
```

## 74HC86 (U15) — DIP-14

```
        ┌───╥───┐
    1A ─┤1  ╨ 14├─ VCC
    1B ─┤2    13├─ 4B
    1Y ─┤3    12├─ 4A
    2A ─┤4    11├─ 4Y
    2B ─┤5    10├─ 3B
    2Y ─┤6     9├─ 3A
   GND ─┤7     8├─ 3Y
        └───────┘
```

## 74HC157 (U16–U17, U25) — DIP-16

```
        ┌───╥───┐
     S ─┤1  ╨ 16├─ VCC
   1A0 ─┤2    15├─ /E
   1B0 ─┤3    14├─ 4A
   1Y0 ─┤4    13├─ 4B
   2A0 ─┤5    12├─ 4Y
   2B0 ─┤6    11├─ 3A
   2Y0 ─┤7    10├─ 3B
   GND ─┤8     9├─ 3Y
        └───────┘
```

## 74HC138 (U18) — DIP-16

```
        ┌───╥───┐
     A ─┤1  ╨ 16├─ VCC
     B ─┤2    15├─ /Y0
     C ─┤3    14├─ /Y1
  /G2A ─┤4    13├─ /Y2
  /G2B ─┤5    12├─ /Y3
    G1 ─┤6    11├─ /Y4
   /Y7 ─┤7    10├─ /Y5
   GND ─┤8     9├─ /Y6
        └───────┘
```

## 74HC245 (U19) — DIP-20

```
        ┌───╥───┐
   DIR ─┤1  ╨ 20├─ VCC
    A1 ─┤2    19├─ /OE
    A2 ─┤3    18├─ B1
    A3 ─┤4    17├─ B2
    A4 ─┤5    16├─ B3
    A5 ─┤6    15├─ B4
    A6 ─┤7    14├─ B5
    A7 ─┤8    13├─ B6
    A8 ─┤9    12├─ B7
   GND ─┤10   11├─ B8
        └───────┘
```

## 74HC74 (U20–U21, U24) — DIP-14

```
        ┌───╥───┐
 /CLR1 ─┤1  ╨ 14├─ VCC
    D1 ─┤2    13├─ /CLR2
  CLK1 ─┤3    12├─ D2
 /PRE1 ─┤4    11├─ CLK2
    Q1 ─┤5    10├─ /PRE2
   /Q1 ─┤6     9├─ Q2
   GND ─┤7     8├─ /Q2
        └───────┘
```

## 74HC08 (U22) — DIP-14

```
        ┌───╥───┐
    1A ─┤1  ╨ 14├─ VCC
    1B ─┤2    13├─ 4B
    1Y ─┤3    12├─ 4A
    2A ─┤4    11├─ 4Y
    2B ─┤5    10├─ 3B
    2Y ─┤6     9├─ 3A
   GND ─┤7     8├─ 3Y
        └───────┘
```

## 74HC32 (U23) — DIP-14

```
        ┌───╥───┐
    1A ─┤1  ╨ 14├─ VCC
    1B ─┤2    13├─ 4B
    1Y ─┤3    12├─ 4A
    2A ─┤4    11├─ 4Y
    2B ─┤5    10├─ 3B
    2Y ─┤6     9├─ 3A
   GND ─┤7     8├─ 3Y
        └───────┘
```

## AT28C256 (ROM) — DIP-28

```
        ┌───╥───┐
   A14 ─┤1  ╨ 28├─ VCC
   A12 ─┤2    27├─ /WE
    A7 ─┤3    26├─ A13
    A6 ─┤4    25├─ A8
    A5 ─┤5    24├─ A9
    A4 ─┤6    23├─ A11
    A3 ─┤7    22├─ /OE
    A2 ─┤8    21├─ A10
    A1 ─┤9    20├─ /CE
    A0 ─┤10   19├─ D7
    D0 ─┤11   18├─ D6
    D1 ─┤12   17├─ D5
    D2 ─┤13   16├─ D4
   GND ─┤14   15├─ D3
        └───────┘
```

## 62256 (RAM) — DIP-28

```
        ┌───╥───┐
   A14 ─┤1  ╨ 28├─ VCC
   A12 ─┤2    27├─ /WE
    A7 ─┤3    26├─ A13
    A6 ─┤4    25├─ A8
    A5 ─┤5    24├─ A9
    A4 ─┤6    23├─ A11
    A3 ─┤7    22├─ /OE
    A2 ─┤8    21├─ A10
    A1 ─┤9    20├─ /CE
    A0 ─┤10   19├─ D7
    D0 ─┤11   18├─ D6
    D1 ─┤12   17├─ D5
    D2 ─┤13   16├─ D4
   GND ─┤14   15├─ D3
        └───────┘
```

---

# ตารางต่อสาย (Wiring Table)

## ไฟเลี้ยง — ต่อก่อนเป็นอันดับแรก!

| ชิป | ขา VCC | ขา GND |
|:---:|:------:|:------:|
| U1–U4 (74HC161) | 16 | 8 |
| U5–U10 (74HC574) | 20 | 10 |
| U11–U12 (74HC161) | 16 | 8 |
| U13–U14 (74HC283) | 16 | 8 |
| U15 (74HC86) | 14 | 7 |
| U16–U17 (74HC157) | 16 | 8 |
| U18 (74HC138) | 16 | 8 |
| U19 (74HC245) | 20 | 10 |
| U20–U21 (74HC74) | 14 | 7 |
| U22 (74HC08) | 14 | 7 |
| U23 (74HC32) | 14 | 7 |
| U24 (74HC74) | 14 | 7 |
| U25 (74HC157) | 16 | 8 |
| ROM (AT28C256) | 28 | 14 |
| RAM (62256) | 28 | 14 |

---

## Program Counter — PC[15:0]

| จาก | ขา | → ไป | ขา | สัญญาณ |
|-----|:--:|------|:--:|--------|
| CLK output | — | U1 | 2 | CLK |
| CLK output | — | U2 | 2 | CLK |
| CLK output | — | U3 | 2 | CLK |
| CLK output | — | U4 | 2 | CLK |
| /RST | — | U1 | 1 | /CLR |
| /RST | — | U2 | 1 | /CLR |
| /RST | — | U3 | 1 | /CLR |
| /RST | — | U4 | 1 | /CLR |
| U1 | 15 (TC) | U2 | 10 (ENT) | carry 0→1 |
| U2 | 15 (TC) | U3 | 10 (ENT) | carry 1→2 |
| U3 | 15 (TC) | U4 | 10 (ENT) | carry 2→3 |
| +5V | — | U1 | 10 (ENT) | enable |
| +5V | — | U1–U4 | 7 (ENP) | enable |
| +5V | — | U1–U4 | 9 (/LD) | ไม่โหลด (Lab 8 จะเปลี่ยน) |

---

## PC → ROM Address

| จาก | ขา | → ไป | ขา | สัญญาณ |
|-----|:--:|------|:--:|--------|
| U1 | 14 (QA) | ROM | 10 (A0) | Address bit 0 |
| U1 | 13 (QB) | ROM | 9 (A1) | Address bit 1 |
| U1 | 12 (QC) | ROM | 8 (A2) | Address bit 2 |
| U1 | 11 (QD) | ROM | 7 (A3) | Address bit 3 |
| U2 | 14 (QA) | ROM | 6 (A4) | Address bit 4 |
| U2 | 13 (QB) | ROM | 5 (A5) | Address bit 5 |
| U2 | 12 (QC) | ROM | 4 (A6) | Address bit 6 |
| U2 | 11 (QD) | ROM | 3 (A7) | Address bit 7 |
| U3 | 14 (QA) | ROM | 25 (A8) | Address bit 8 |
| U3 | 13 (QB) | ROM | 24 (A9) | Address bit 9 |
| U3 | 12 (QC) | ROM | 21 (A10) | Address bit 10 |
| U3 | 11 (QD) | ROM | 23 (A11) | Address bit 11 |
| U4 | 14 (QA) | ROM | 2 (A12) | Address bit 12 |
| U4 | 13 (QB) | ROM | 26 (A13) | Address bit 13 |
| U4 | 12 (QC) | ROM | 1 (A14) | Address bit 14 |

---

## ROM → Bus Buffer → Data Bus

| จาก | ขา | → ไป | ขา | สัญญาณ |
|-----|:--:|------|:--:|--------|
| ROM | 11 (D0) | U19 | 2 (A1) | Data bit 0 |
| ROM | 12 (D1) | U19 | 3 (A2) | Data bit 1 |
| ROM | 13 (D2) | U19 | 4 (A3) | Data bit 2 |
| ROM | 15 (D3) | U19 | 5 (A4) | Data bit 3 |
| ROM | 16 (D4) | U19 | 6 (A5) | Data bit 4 |
| ROM | 17 (D5) | U19 | 7 (A6) | Data bit 5 |
| ROM | 18 (D6) | U19 | 8 (A7) | Data bit 6 |
| ROM | 19 (D7) | U19 | 9 (A8) | Data bit 7 |
| U19 | 18 (B1) | Data Bus | — | D0 |
| U19 | 17 (B2) | Data Bus | — | D1 |
| U19 | 16 (B3) | Data Bus | — | D2 |
| U19 | 15 (B4) | Data Bus | — | D3 |
| U19 | 14 (B5) | Data Bus | — | D4 |
| U19 | 13 (B6) | Data Bus | — | D5 |
| U19 | 12 (B7) | Data Bus | — | D6 |
| U19 | 11 (B8) | Data Bus | — | D7 |
| +5V | — | U19 | 1 (DIR) | A→B |
| GND | — | U19 | 19 (/OE) | always enabled |
| GND | — | ROM | 22 (/OE) | always read |
| GND | — | ROM | 20 (/CE) | always selected (for testing) |
| +5V | — | ROM | 27 (/WE) | write disabled |

---

## ALU — Adder + XOR

| จาก | ขา | → ไป | ขา | สัญญาณ |
|-----|:--:|------|:--:|--------|
| U7 (a0) | 19 (Q0) | U13 | 5 (A1) | a0 bit 0 |
| U7 (a0) | 18 (Q1) | U13 | 3 (A2) | a0 bit 1 |
| U7 (a0) | 17 (Q2) | U13 | 14 (A3) | a0 bit 2 |
| U7 (a0) | 16 (Q3) | U13 | 12 (A4) | a0 bit 3 |
| U7 (a0) | 15 (Q4) | U14 | 5 (A1) | a0 bit 4 |
| U7 (a0) | 14 (Q5) | U14 | 3 (A2) | a0 bit 5 |
| U7 (a0) | 13 (Q6) | U14 | 14 (A3) | a0 bit 6 |
| U7 (a0) | 12 (Q7) | U14 | 12 (A4) | a0 bit 7 |
| U15 | 3 (1Y) | U13 | 6 (B1) | B0 XOR SUB |
| U15 | 6 (2Y) | U13 | 2 (B2) | B1 XOR SUB |
| U15 | 8 (3Y) | U13 | 15 (B3) | B2 XOR SUB |
| U15 | 11 (4Y) | U13 | 11 (B4) | B3 XOR SUB |
| U13 | 9 (C4) | U14 | 7 (C0) | carry ทด |
| U13 | 4 (S1) | U7 | 2 (D0) | result bit 0 |
| U13 | 1 (S2) | U7 | 3 (D1) | result bit 1 |
| U13 | 13 (S3) | U7 | 4 (D2) | result bit 2 |
| U13 | 10 (S4) | U7 | 5 (D3) | result bit 3 |
| U14 | 4 (S1) | U7 | 6 (D4) | result bit 4 |
| U14 | 1 (S2) | U7 | 7 (D5) | result bit 5 |
| U14 | 13 (S3) | U7 | 8 (D6) | result bit 6 |
| U14 | 10 (S4) | U7 | 9 (D7) | result bit 7 |

---

## เคล็ดลับสำหรับนักเรียน

1. **ต่อไฟก่อน** — VCC และ GND ทุกชิปก่อนต่อสายอื่น
2. **ตรวจทีละชิป** — ต่อเสร็จ 1 ชิป ทดสอบก่อนไปชิปถัดไป
3. **สายสี** — แดง=+5V, ดำ=GND, เหลือง=address, น้ำเงิน=data, เขียว=control
4. **สายสั้น** — ยิ่งสั้นยิ่งดี ลดสัญญาณรบกวน
5. **ขา 1 อยู่ตรงรอยบาก** — ดูรอยบากบนชิปเพื่อหาขา 1
6. **ใช้ STEP mode** — ทดสอบทีละ clock ก่อนเปิด RUN
