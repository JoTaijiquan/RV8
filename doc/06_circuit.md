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
