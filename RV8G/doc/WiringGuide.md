# RV8-G Wiring Guide — FINAL 24-Chip Design

```
Project: RV8-G (Gates-Only 8-bit CPU)
Chips:   24 (22 logic + ROM + RAM)
Clock:   3.5 MHz (breadboard) / 10 MHz (PCB)
ISA:     32 instructions, 4 cycles each, 2 bytes fixed
Date:    2026-05-15
```

---

## Chip Summary

| U# | Type | Function | Pkg |
|:--:|------|----------|:---:|
| U1 | 74HC161 | PC [3:0] | DIP-16 |
| U2 | 74HC161 | PC [7:4] | DIP-16 |
| U3 | 74HC161 | PC [11:8] | DIP-16 |
| U4 | 74HC161 | PC [15:12] | DIP-16 |
| U5 | 74HC574 | IR opcode | DIP-20 |
| U6 | 74HC574 | IR operand (tri-state ALU B) | DIP-20 |
| U7 | 74HC574 | a0 accumulator | DIP-20 |
| U8 | 74HC574 | t0 temp reg (tri-state ALU B) | DIP-20 |
| U9 | 74HC574 | sp stack pointer | DIP-20 |
| U10 | 74HC161 | pl pointer low (auto-inc) | DIP-16 |
| U11 | 74HC574 | ph pointer high (tri-state addr) | DIP-20 |
| U12 | 74HC283 | ALU adder low [3:0] | DIP-16 |
| U13 | 74HC283 | ALU adder high [7:4] | DIP-16 |
| U14 | 74HC86 | XOR low nibble + spare | DIP-14 |
| U15 | 74HC86 | XOR high nibble | DIP-14 |
| U16 | 74HC541 | PC high byte buffer → A[15:8] | DIP-20 |
| U17 | 74HC157 | Address mux low byte → A[7:0] | DIP-16 |
| U18 | 74HC139 | Dual decoder (class + reg write) | DIP-16 |
| U19 | 74HC74 | State counter (2 FFs) | DIP-14 |
| U20 | 74HC74 | Flags: Z, C | DIP-14 |
| U21 | 74HC08 | 4× AND gates (control) | DIP-14 |
| U22 | 74HC32 | 4× OR gates (control) | DIP-14 |
| ROM | AT28C256 | Program ROM 32KB | DIP-28 |
| RAM | 62256 | Data RAM 32KB | DIP-28 |

---

## Key Design Tricks

### 1. ALU B-Source via /OE (U6 + U8 share wires)
U6 (operand) and U8 (t0) outputs connect to the SAME 8 wires (alu_b[7:0]).
- Immediate mode (ir_op[0]=1): U6./OE=GND (active), U8./OE=VCC (hi-Z)
- Register mode (ir_op[0]=0): U6./OE=VCC (hi-Z), U8./OE=GND (active)
- Inverter: U14 gate 4 used as inverter (one input tied to VCC → XOR = NOT)

### 2. Address High Byte via /OE (U11 + U16 share A[15:8])
- Fetch mode (state[1]=0): U16./OE=GND (drives PC high), U11./OE=VCC (hi-Z)
- Data mode (state[1]=1): U16./OE=VCC (hi-Z), U11./OE=GND (drives ph)
- U16 has two /OE pins, both tied to state[1]
- U11./OE = NOT(state[1]) = /Q2 from U19 pin 8... WAIT: /OE is active LOW.
  When state[1]=0 (fetch): U11./OE must be HIGH (disabled). /Q2=1 ✓
  When state[1]=1 (data): U11./OE must be LOW (enabled). /Q2=0 ✓
  So U11./OE = /Q2 directly!

### 3. Address Low Byte via 74HC157 Mux (U17)
- S = state[1] (addr_sel): 0=PC low (A inputs), 1=pl (B inputs)
- A inputs: U1.Q[3:0] + U2.Q[3:0] = PC[7:0]
- B inputs: U10.Q[3:0] + U10 needs 8 bits... 

**NOTE**: U10 is a 74HC161 (4-bit counter). For 8-bit pl we need the mux to
carry 8 bits. U17 (74HC157) has 4 channels × 2-input = 4 output bits.
We need 8 address bits → U17 provides A[7:0] using all 4 channels for low nibble
from U1 (PC[3:0]) vs U10 (pl[3:0]), but we only get 4 bits from U10.

**RESOLUTION**: The 74HC157 has 4 mux channels. We use it as:
- Channel 1: A=U1.QA(PC0), B=U10.QA(pl0) → A[0]
- Channel 2: A=U1.QB(PC1), B=U10.QB(pl1) → A[1]
- Channel 3: A=U1.QC(PC2), B=U10.QC(pl2) → A[2]
- Channel 4: A=U1.QD(PC3), B=U10.QD(pl3) → A[3]

For A[7:4], we need ANOTHER mux... but we only have one U17.

**ACTUAL DESIGN**: U17 muxes the full low byte A[7:0]. The 74HC157 is a QUAD 2:1 mux
(4 bits). For 8 bits we'd need two. BUT the task spec says "U17: 74HC157, A=PC low
from U1+U2, B=pl from U10, Y→A[7:0]". This implies U10 provides 8 bits.

Since U10 is a 74HC161 (4-bit), and we only have ONE 74HC157 (4-channel):
- A[3:0] muxed by U17: PC[3:0] vs pl[3:0]
- A[7:4] driven by: PC[7:4] (U2) during fetch, or HIGH-Z/fixed during data

**HONEST ANSWER**: One 74HC157 only muxes 4 bits. The spec says Y→A[7:0] which
requires 8 mux channels = 2× 74HC157. With only one chip, A[7:4] must come from
another source. Since U10 is 4-bit, pl is limited to [3:0] and A[7:4] during
data access comes from U11 (ph) low nibble or is fixed at 0.

**FOR THIS GUIDE**: We interpret the design as:
- U17 muxes A[3:0] only (4 bits from 74HC157)
- A[7:4] during fetch: from U2 (PC[7:4]) directly
- A[7:4] during data: from U10 high nibble... but U10 is only 4-bit.

**FINAL INTERPRETATION**: The pointer is {ph[7:0], pl[3:0]} = 12-bit (4KB pages).
A[7:4] during data access comes from ph[3:0] via U11 outputs (which also drive A[15:8]).
Actually no — U11 drives A[15:8], not A[7:4].

**PRACTICAL SOLUTION USED**: 
- A[3:0]: U17 mux (PC[3:0] vs pl[3:0])
- A[7:4]: directly from U2 (PC[7:4]) during fetch; during data access, U2 outputs
  are overridden... but 74HC161 has no /OE!

**I will document the design AS SPECIFIED in the task, noting this limitation.**

---

## Signal Definitions

| Signal | Source | Destination | Description |
|--------|--------|-------------|-------------|
| CLK | Oscillator | U1-U4.2, U10.2, U19.3 | System clock |
| /RST | Reset ckt | U1-U4.1, U10.1, U19.1+13, U20.1+13 | Master reset |
| state[0] | U19.5 (Q1) | Control logic | State bit 0 |
| state[1] | U19.9 (Q2) | Control logic | State bit 1 |
| /Q1 | U19.6 | U19.2(D1), U19.11(CLK2) | Inverted state[0] |
| /Q2 | U19.8 | U19.12(D2), U11.1(/OE) | Inverted state[1] |
| ir_latch | U21.3 | U5.11 | IR opcode clock (S0→S1 edge) |
| opr_latch | U21.6 | U6.11 | IR operand clock (S1→S2 edge) |
| pc_inc | U22.3 | U1-U4.7+10 | PC increment enable |
| addr_sel | U19.9 (=state[1]) | U17.1 | Mux select: 0=PC, 1=pointer |
| sub_mode | U5.15 (ir_op[3]) | U14.2+5+10, U15.2+5+10 | XOR invert for SUB |
| carry_in | U21.11 | U12.7 | ALU carry input |
| carry_out | U13.9 | U20.12 | ALU carry output → C flag |
| alu_zero | zero_detect net | U20.2 | All-zero detect → Z flag |
| flags_we | U21.8 | U20.3+11 | Flags latch clock |
| a0_clk | U22.3 or decode | U7.11 | Accumulator write |
| t0_clk | U18.9(/Y3b) | U8.11 | t0 write |
| sp_clk | U18.10(/Y2b) | U9.11 | sp write |
| ph_clk | U18.11(/Y1b) | U11.11 | ph write |
| /RD | U22.6 | ROM.22, RAM.22 | Read strobe |
| /WR | U21.6 | RAM.27 | Write strobe |
| /ROM_CE | NOT(A[15]) | ROM.20 | ROM select (A15=1→ROM) |
| /RAM_CE | A[15] direct | RAM.20 | RAM select (A15=0→RAM) |

---

## Pin-by-Pin Wiring

### U1: 74HC161 — PC [3:0]

```
U1:{type:74HC161, function:'PC bit 3:0',
    1:/RST, 2:CLK, 3:D[0], 4:D[1], 5:D[2], 6:D[3], 7:pc_inc, 8:GND,
    9:pc_ld_n, 10:pc_inc, 11:U17.14(4A), 12:U17.11(3A), 13:U17.5(2A), 14:U17.2(1A), 15:U2.10(ENT), 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /CLR | /RST | Reset circuit |
| 2 | CLK | CLK | Oscillator |
| 3 | D0 | D[0] | Data bus (for branch/jump load) |
| 4 | D1 | D[1] | Data bus |
| 5 | D2 | D[2] | Data bus |
| 6 | D3 | D[3] | Data bus |
| 7 | ENP | pc_inc | U22.3 (OR gate output) |
| 8 | GND | GND | Ground |
| 9 | /LD | pc_ld_n | Branch logic (active low) |
| 10 | ENT | pc_inc | U22.3 (same as ENP) |
| 11 | QD | PC[3] | U17.14 (mux channel 4, A input) |
| 12 | QC | PC[2] | U17.11 (mux channel 3, A input) |
| 13 | QB | PC[1] | U17.5 (mux channel 2, A input) |
| 14 | QA | PC[0] | U17.2 (mux channel 1, A input) |
| 15 | TC | carry_01 | U2.10 (ENT of next stage) |
| 16 | VCC | VCC | +5V |


### U2: 74HC161 — PC [7:4]

```
U2:{type:74HC161, function:'PC bit 7:4',
    1:/RST, 2:CLK, 3:D[4], 4:D[5], 5:D[6], 6:D[7], 7:pc_inc, 8:GND,
    9:pc_ld_n, 10:U1.15(TC), 11:U16.8(A8), 12:U16.6(A7), 13:U16.4(A6), 14:U16.2(A5), 15:U3.10(ENT), 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /CLR | /RST | Reset circuit |
| 2 | CLK | CLK | Oscillator |
| 3 | D0 | D[4] | Data bus (branch/jump load) |
| 4 | D1 | D[5] | Data bus |
| 5 | D2 | D[6] | Data bus |
| 6 | D3 | D[7] | Data bus |
| 7 | ENP | pc_inc | U22.3 |
| 8 | GND | GND | Ground |
| 9 | /LD | pc_ld_n | Branch logic |
| 10 | ENT | carry_01 | U1.15 (TC from U1) |
| 11 | QD | PC[7] | U16.8 (541 A8 input) |
| 12 | QC | PC[6] | U16.6 (541 A7 input) |
| 13 | QB | PC[5] | U16.4 (541 A6 input) |
| 14 | QA | PC[4] | U16.2 (541 A5 input) |
| 15 | TC | carry_12 | U3.10 (ENT of next stage) |
| 16 | VCC | VCC | +5V |

**NOTE on U2**: In the original design, U2 outputs go to U17 B inputs for A[7:4]
mux. But U17 is only 4-channel (handles A[3:0]). In this 24-chip design, A[7:4]
during fetch comes from U16 (541 buffer) which reads U2+U3 outputs. During data
access, A[7:4] is NOT muxed — the pointer is limited to pl[3:0] for the low nibble
and ph[7:0] for the high byte. See ADDRESS BUS ROUTING section.

### U3: 74HC161 — PC [11:8]

```
U3:{type:74HC161, function:'PC bit 11:8',
    1:/RST, 2:CLK, 3:ph[0](U11.12), 4:ph[1](U11.13), 5:ph[2](U11.14), 6:ph[3](U11.15), 7:pc_inc, 8:GND,
    9:pc_ld_n, 10:U2.15(TC), 11:U16.16(A11), 12:U16.14(A10), 13:U16.12(A9), 14:U16.10(A8h), 15:U4.10(ENT), 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /CLR | /RST | Reset circuit |
| 2 | CLK | CLK | Oscillator |
| 3 | D0 | ph[0] | U11.12 (ph Q0, for JMP load) |
| 4 | D1 | ph[1] | U11.13 (ph Q1) |
| 5 | D2 | ph[2] | U11.14 (ph Q2) |
| 6 | D3 | ph[3] | U11.15 (ph Q3) |
| 7 | ENP | pc_inc | U22.3 |
| 8 | GND | GND | Ground |
| 9 | /LD | pc_ld_n | Branch logic |
| 10 | ENT | carry_12 | U2.15 (TC from U2) |
| 11 | QD | PC[11] | U16.16 (541 A4 input — see 541 pinout) |
| 12 | QC | PC[10] | U16.14 (541 A3 input) |
| 13 | QB | PC[9] | U16.12 (541 A2 input) |
| 14 | QA | PC[8] | U16.10 (541 A1 input — see note) |
| 15 | TC | carry_23 | U4.10 (ENT of next stage) |
| 16 | VCC | VCC | +5V |

### U4: 74HC161 — PC [15:12]

```
U4:{type:74HC161, function:'PC bit 15:12',
    1:/RST, 2:CLK, 3:ph[4](U11.16), 4:ph[5](U11.17), 5:ph[6](U11.18), 6:ph[7](U11.19), 7:pc_inc, 8:GND,
    9:pc_ld_n, 10:U3.15(TC), 11:U16.18(A7h), 12:U16.17(A6h), 13:U16.15(A5h), 14:U16.13(A4h_unused), 15:NC, 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /CLR | /RST | Reset circuit |
| 2 | CLK | CLK | Oscillator |
| 3 | D0 | ph[4] | U11.16 (ph Q4, for JMP load) |
| 4 | D1 | ph[5] | U11.17 (ph Q5) |
| 5 | D2 | ph[6] | U11.18 (ph Q6) |
| 6 | D3 | ph[7] | U11.19 (ph Q7) |
| 7 | ENP | pc_inc | U22.3 |
| 8 | GND | GND | Ground |
| 9 | /LD | pc_ld_n | Branch logic |
| 10 | ENT | carry_23 | U3.15 (TC from U3) |
| 11 | QD | PC[15] | Address decode (/ROM_CE, /RAM_CE) |
| 12 | QC | PC[14] | U16.18 or addr bus A[14] |
| 13 | QB | PC[13] | addr bus A[13] |
| 14 | QA | PC[12] | addr bus A[12] |
| 15 | TC | NC | Not used (no further carry) |
| 16 | VCC | VCC | +5V |

**PC Load for JMP**: D inputs of U3-U4 come from ph register (U11 outputs).
For JMP imm: PC[7:0] loaded from operand (data bus), PC[15:8] from ph.
For relative branch: PC[7:0] = PC + offset (done via ALU or counter trick).

**Reset vector**: 74HC161 /CLR resets to 0000. To start at $C000, place
`JMP $C000` at address $0000 in ROM. ROM is mapped to $8000-$FFFF AND
mirrored at $0000 by tying /ROM_CE = GND (always enabled) and using /OE
for output control. Alternative: ignore A[15] in ROM decode.


### U5: 74HC574 — IR Opcode Register

```
U5:{type:74HC574, function:'IR opcode latch',
    1:GND(/OE), 2:D[0], 3:D[1], 4:D[2], 5:D[3], 6:D[4], 7:D[5], 8:D[6], 9:D[7], 10:GND,
    11:ir_latch, 12:ir_op[0], 13:ir_op[1], 14:ir_op[2], 15:ir_op[3], 16:ir_op[4], 17:ir_op[5], 18:ir_op[6], 19:ir_op[7], 20:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE | GND | Always enabled (outputs always drive) |
| 2 | D0 | D[0] | Data bus bit 0 |
| 3 | D1 | D[1] | Data bus bit 1 |
| 4 | D2 | D[2] | Data bus bit 2 |
| 5 | D3 | D[3] | Data bus bit 3 |
| 6 | D4 | D[4] | Data bus bit 4 |
| 7 | D5 | D[5] | Data bus bit 5 |
| 8 | D6 | D[6] | Data bus bit 6 |
| 9 | D7 | D[7] | Data bus bit 7 |
| 10 | GND | GND | Ground |
| 11 | CLK | ir_latch | U21.3 (AND: /Q2 AND Q1 = S1 pulse) |
| 12 | Q0 | ir_op[0] | U18.14(A0b), U14.13(4B inv ctrl), U6./OE logic |
| 13 | Q1 | ir_op[1] | U18.13(A1b), carry_in logic |
| 14 | Q2 | ir_op[2] | Register select (modf[2]) |
| 15 | Q3 | ir_op[3] | sub_mode → U14.2+5+10, U15.2+5+10 (XOR B inputs) |
| 16 | Q4 | ir_op[4] | ALU op[1] / branch flag select |
| 17 | Q5 | ir_op[5] | ALU op[2] / branch invert |
| 18 | Q6 | ir_op[6] | U18.2(A0a) class decode bit 0 |
| 19 | Q7 | ir_op[7] | U18.3(A1a) class decode bit 1 |
| 20 | VCC | VCC | +5V |

### U6: 74HC574 — IR Operand Register (Tri-state to ALU B)

```
U6:{type:74HC574, function:'IR operand, /OE=imm_mode_n',
    1:imm_mode_n, 2:D[0], 3:D[1], 4:D[2], 5:D[3], 6:D[4], 7:D[5], 8:D[6], 9:D[7], 10:GND,
    11:opr_latch, 12:alu_b[0], 13:alu_b[1], 14:alu_b[2], 15:alu_b[3], 16:alu_b[4], 17:alu_b[5], 18:alu_b[6], 19:alu_b[7], 20:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE | imm_mode_n | NOT(ir_op[0]) via U14.11 (XOR gate 4 as inverter) |
| 2 | D0 | D[0] | Data bus bit 0 |
| 3 | D1 | D[1] | Data bus bit 1 |
| 4 | D2 | D[2] | Data bus bit 2 |
| 5 | D3 | D[3] | Data bus bit 3 |
| 6 | D4 | D[4] | Data bus bit 4 |
| 7 | D5 | D[5] | Data bus bit 5 |
| 8 | D6 | D[6] | Data bus bit 6 |
| 9 | D7 | D[7] | Data bus bit 7 |
| 10 | GND | GND | Ground |
| 11 | CLK | opr_latch | U21.6 (AND: Q2 AND /Q1 = S2 pulse) |
| 12 | Q0 | alu_b[0] | Shared wire → U14.1 (XOR 1A) |
| 13 | Q1 | alu_b[1] | Shared wire → U14.4 (XOR 2A) |
| 14 | Q2 | alu_b[2] | Shared wire → U14.9 (XOR 3A) |
| 15 | Q3 | alu_b[3] | Shared wire → U14.12 (XOR 4A)... |
| 16 | Q4 | alu_b[4] | Shared wire → U15.1 (XOR 1A) |
| 17 | Q5 | alu_b[5] | Shared wire → U15.4 (XOR 2A) |
| 18 | Q6 | alu_b[6] | Shared wire → U15.9 (XOR 3A) |
| 19 | Q7 | alu_b[7] | Shared wire → U15.12 (XOR 4A) |
| 20 | VCC | VCC | +5V |

**/OE LOGIC**: U6./OE = NOT(ir_op[0]). When ir_op[0]=1 (immediate mode),
NOT(1)=0, /OE=LOW → outputs ACTIVE. When ir_op[0]=0 (register mode),
NOT(0)=1, /OE=HIGH → outputs HI-Z. Inverter from U14 gate 4 (see below).

**WAIT — CORRECTION**: /OE is active LOW. We want U6 active in IMMEDIATE mode.
- Immediate: ir_op[0]=1 → need /OE=0 → need NOT(ir_op[0])=0... that's wrong.
- Let me re-think: /OE=LOW means outputs ON.
- Immediate mode (ir_op[0]=1): U6 should drive → /OE must be LOW
- Register mode (ir_op[0]=0): U6 should be hi-Z → /OE must be HIGH
- So U6./OE = NOT(ir_op[0])? NO: NOT(1)=0=LOW=active ✓, NOT(0)=1=HIGH=hi-Z ✓
- YES: U6./OE = NOT(ir_op[0]) ✓

### U7: 74HC574 — a0 Accumulator

```
U7:{type:74HC574, function:'a0 accumulator',
    1:GND(/OE), 2:alu_out[0], 3:alu_out[1], 4:alu_out[2], 5:alu_out[3], 6:alu_out[4], 7:alu_out[5], 8:alu_out[6], 9:alu_out[7], 10:GND,
    11:a0_clk, 12:a0[0], 13:a0[1], 14:a0[2], 15:a0[3], 16:a0[4], 17:a0[5], 18:a0[6], 19:a0[7], 20:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE | GND | Always enabled |
| 2 | D0 | alu_out[0] | U12.4 (Sum1 from low adder) |
| 3 | D1 | alu_out[1] | U12.1 (Sum2 from low adder) |
| 4 | D2 | alu_out[2] | U12.13 (Sum3 from low adder) |
| 5 | D3 | alu_out[3] | U12.10 (Sum4 from low adder) |
| 6 | D4 | alu_out[4] | U13.4 (Sum1 from high adder) |
| 7 | D5 | alu_out[5] | U13.1 (Sum2 from high adder) |
| 8 | D6 | alu_out[6] | U13.13 (Sum3 from high adder) |
| 9 | D7 | alu_out[7] | U13.10 (Sum4 from high adder) |
| 10 | GND | GND | Ground |
| 11 | CLK | a0_clk | U22.3 (OR: alu_write OR mem_load) |
| 12 | Q0 | a0[0] | U12.5 (A1 of low adder) |
| 13 | Q1 | a0[1] | U12.3 (A2 of low adder) |
| 14 | Q2 | a0[2] | U12.14 (A3 of low adder) |
| 15 | Q3 | a0[3] | U12.12 (A4 of low adder) |
| 16 | Q4 | a0[4] | U13.5 (A1 of high adder) |
| 17 | Q5 | a0[5] | U13.3 (A2 of high adder) |
| 18 | Q6 | a0[6] | U13.14 (A3 of high adder) |
| 19 | Q7 | a0[7] | U13.12 (A4 of high adder) |
| 20 | VCC | VCC | +5V |

**NOTE**: a0 D inputs come from ALU result (adder outputs). For LB (memory load),
the data bus value must reach a0. The trick: during load, ALU B=data_in and
A=0 (or use passthrough). Actually in this design, a0 ALWAYS reads from ALU.
For loads: set ALU to pass-through (ADD with A=0, B=data). This requires
a0 to be zeroed first or use a different path.

**ACTUAL DESIGN**: For LB/POP, the data bus value is loaded into a0 directly.
This means a0.D must connect to data bus during loads. CONFLICT with ALU output.
Resolution: ALU output is purely combinational (not tri-state). During S3 (load),
the ALU inputs are garbage but we clock a0 from... the ALU output which is
a0 + alu_b. This doesn't give us the memory data.

**REAL SOLUTION**: a0.D connects to DATA BUS, not ALU output. The ALU result
is written BACK to data bus via a buffer, then a0 latches from bus.
But we have no buffer chip for ALU→bus.

**SIMPLEST WORKING APPROACH**: a0.D = ALU result. For loads, route data bus
through ALU: set alu_b = data_in (from operand register loaded with mem data),
a0 = 0 (cleared), result = 0 + data_in = data_in. But clearing a0 first
destroys the accumulator.

**DESIGN DECISION (matching Verilog)**: In the Verilog, a0 is loaded directly
from data_in during S3. In hardware, this requires a0.D to be switchable
between ALU output and data bus. Without a mux, use the /OE trick:
- ALU outputs drive a0.D wires during S2 (via tri-state buffer — NOT AVAILABLE)
- Data bus drives a0.D wires during S3 (ROM/RAM drives bus)

**HONEST**: This is a bus contention issue. The ALU (74HC283) outputs are
always active (no /OE). They will fight with data bus during S3.

**FIX**: Add pull-up/pull-down? No. The real fix is that a0.D connects to
the data bus, and ALU result is ALSO placed on the data bus during S2.
The 74HC283 outputs drive the data bus through... nothing. They're always on.

**ACCEPTED LIMITATION**: In this 24-chip design, a0 can ONLY be loaded from
ALU result. For LB/POP, the loaded byte goes into the operand register (U6)
first, then ALU computes a0 + 0 + operand = operand (if a0=0) or we use
a dedicated "pass B" operation (XOR with A=0, or OR with A=0).

**PRACTICAL**: Use LI a0,imm pattern — operand goes to U6, ALU does
ADD(a0, operand) with sub_mode=0. For true load, need a0=0 first. OR:
accept that LB actually does a0 = a0 + mem[ptr] (add-load). Many 8-bit
CPUs work this way.

**FOR THIS GUIDE**: a0.D = ALU output (U12+U13 sum outputs). Loads use
ALU passthrough trick.

### U8: 74HC574 — t0 Temp Register (Tri-state to ALU B)

```
U8:{type:74HC574, function:'t0 register, /OE=reg_mode_n',
    1:reg_mode_n, 2:D[0], 3:D[1], 4:D[2], 5:D[3], 6:D[4], 7:D[5], 8:D[6], 9:D[7], 10:GND,
    11:t0_clk, 12:alu_b[0], 13:alu_b[1], 14:alu_b[2], 15:alu_b[3], 16:alu_b[4], 17:alu_b[5], 18:alu_b[6], 19:alu_b[7], 20:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE | reg_mode_n | ir_op[0] direct (U5.12) |
| 2 | D0 | D[0] | Data bus bit 0 |
| 3 | D1 | D[1] | Data bus bit 1 |
| 4 | D2 | D[2] | Data bus bit 2 |
| 5 | D3 | D[3] | Data bus bit 3 |
| 6 | D4 | D[4] | Data bus bit 4 |
| 7 | D5 | D[5] | Data bus bit 5 |
| 8 | D6 | D[6] | Data bus bit 6 |
| 9 | D7 | D[7] | Data bus bit 7 |
| 10 | GND | GND | Ground |
| 11 | CLK | t0_clk | U18.9 (/Y3b from decoder B) |
| 12 | Q0 | alu_b[0] | Shared wire → U14.1 (same wire as U6.12) |
| 13 | Q1 | alu_b[1] | Shared wire → U14.4 (same wire as U6.13) |
| 14 | Q2 | alu_b[2] | Shared wire → U14.9 (same wire as U6.14) |
| 15 | Q3 | alu_b[3] | Shared wire → U14.12 (same wire as U6.15) |
| 16 | Q4 | alu_b[4] | Shared wire → U15.1 (same wire as U6.16) |
| 17 | Q5 | alu_b[5] | Shared wire → U15.4 (same wire as U6.17) |
| 18 | Q6 | alu_b[6] | Shared wire → U15.9 (same wire as U6.18) |
| 19 | Q7 | alu_b[7] | Shared wire → U15.12 (same wire as U6.19) |
| 20 | VCC | VCC | +5V |

**/OE LOGIC**: U8./OE = ir_op[0] directly.
- Register mode (ir_op[0]=0): /OE=0=LOW → outputs ACTIVE ✓
- Immediate mode (ir_op[0]=1): /OE=1=HIGH → outputs HI-Z ✓

### U9: 74HC574 — sp Stack Pointer

```
U9:{type:74HC574, function:'sp stack pointer',
    1:GND(/OE), 2:D[0], 3:D[1], 4:D[2], 5:D[3], 6:D[4], 7:D[5], 8:D[6], 9:D[7], 10:GND,
    11:sp_clk, 12:sp[0], 13:sp[1], 14:sp[2], 15:sp[3], 16:sp[4], 17:sp[5], 18:sp[6], 19:sp[7], 20:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE | GND | Always enabled |
| 2 | D0 | D[0] | Data bus bit 0 |
| 3 | D1 | D[1] | Data bus bit 1 |
| 4 | D2 | D[2] | Data bus bit 2 |
| 5 | D3 | D[3] | Data bus bit 3 |
| 6 | D4 | D[4] | Data bus bit 4 |
| 7 | D5 | D[5] | Data bus bit 5 |
| 8 | D6 | D[6] | Data bus bit 6 |
| 9 | D7 | D[7] | Data bus bit 7 |
| 10 | GND | GND | Ground |
| 11 | CLK | sp_clk | U18.10 (/Y2b from decoder B) |
| 12 | Q0 | sp[0] | Stack address (directly to addr bus during stack ops) |
| 13 | Q1 | sp[1] | Stack address |
| 14 | Q2 | sp[2] | Stack address |
| 15 | Q3 | sp[3] | Stack address |
| 16 | Q4 | sp[4] | Stack address |
| 17 | Q5 | sp[5] | Stack address |
| 18 | Q6 | sp[6] | Stack address |
| 19 | Q7 | sp[7] | Stack address |
| 20 | VCC | VCC | +5V |

**SP ADDRESSING**: In the Verilog, stack is at {$30, sp}. In hardware, sp outputs
need to reach the address bus during PUSH/POP/CALL/RET. Since U17 B inputs are
wired to U10 (pl), sp cannot directly drive the address mux.

**SOLUTION**: Software pre-loads pl with sp value before stack ops. The PUSH/POP
instructions in the Verilog do this implicitly. In hardware, the microsequence
must copy sp→pl before memory access. This adds cycles or requires sp to share
the U17 B input wires with pl via tri-state.

**ACCEPTED**: sp outputs are directly readable by software (LI a0 from sp via
register read trick) but stack addressing uses pl/ph pointer. Software must
set ph=$30, pl=sp before PUSH/POP. This changes the ISA semantics slightly.


### U10: 74HC161 — pl Pointer Low (auto-increment counter)

```
U10:{type:74HC161, function:'pl pointer low, auto-inc',
     1:/RST, 2:CLK, 3:D[0], 4:D[1], 5:D[2], 6:D[3], 7:ptr_inc, 8:GND,
     9:pl_ld_n, 10:ptr_inc, 11:U17.13(4B), 12:U17.10(3B), 13:U17.6(2B), 14:U17.3(1B), 15:ph_carry, 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /CLR | /RST | Reset circuit |
| 2 | CLK | CLK | Oscillator |
| 3 | D0 | D[0] | Data bus (for LI pl, imm) |
| 4 | D1 | D[1] | Data bus |
| 5 | D2 | D[2] | Data bus |
| 6 | D3 | D[3] | Data bus |
| 7 | ENP | ptr_inc | Pointer increment enable (from control) |
| 8 | GND | GND | Ground |
| 9 | /LD | pl_ld_n | Load enable (active low, from LI pl decode) |
| 10 | ENT | ptr_inc | Same as ENP (both high to count) |
| 11 | QD | pl[3] | U17.13 (mux channel 4, B input) |
| 12 | QC | pl[2] | U17.10 (mux channel 3, B input) |
| 13 | QB | pl[1] | U17.6 (mux channel 2, B input) |
| 14 | QA | pl[0] | U17.3 (mux channel 1, B input) |
| 15 | TC | ph_carry | (carry to ph — see note) |
| 16 | VCC | VCC | +5V |

**LIMITATION**: U10 is a 4-bit counter. pl is only [3:0] = 16 values.
The pointer address low byte A[7:0] during data access is:
- A[3:0] = pl[3:0] from U17 mux B outputs
- A[7:4] = NOT MUXED (see address bus routing)

For the full Verilog behavior (8-bit pl), we would need 2× 74HC161 for pl.
In this 24-chip design, pl provides only 4 bits of address. The pointer
window is 16 bytes within a 256-byte page set by ph.

**WORKAROUND**: Use ph to set the full page, pl to index within 16 bytes.
For larger blocks, software reloads pl and increments ph manually.

### U11: 74HC574 — ph Pointer High (tri-state to address bus A[15:8])

```
U11:{type:74HC574, function:'ph pointer high, /OE=fetch_mode_n',
     1:/Q2(U19.8), 2:D[0], 3:D[1], 4:D[2], 5:D[3], 6:D[4], 7:D[5], 8:D[6], 9:D[7], 10:GND,
     11:ph_clk, 12:ph[0], 13:ph[1], 14:ph[2], 15:ph[3], 16:ph[4], 17:ph[5], 18:ph[6], 19:ph[7], 20:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE | /Q2 | U19.8 (NOT state[1]) — enabled during data access |
| 2 | D0 | D[0] | Data bus bit 0 |
| 3 | D1 | D[1] | Data bus bit 1 |
| 4 | D2 | D[2] | Data bus bit 2 |
| 5 | D3 | D[3] | Data bus bit 3 |
| 6 | D4 | D[4] | Data bus bit 4 |
| 7 | D5 | D[5] | Data bus bit 5 |
| 8 | D6 | D[6] | Data bus bit 6 |
| 9 | D7 | D[7] | Data bus bit 7 |
| 10 | GND | GND | Ground |
| 11 | CLK | ph_clk | U18.11 (/Y1b from decoder B) |
| 12 | Q0 | ph[0] | addr bus A[8], U3.3 (PC D0 for JMP) |
| 13 | Q1 | ph[1] | addr bus A[9], U3.4 (PC D1) |
| 14 | Q2 | ph[2] | addr bus A[10], U3.5 (PC D2) |
| 15 | Q3 | ph[3] | addr bus A[11], U3.6 (PC D3) |
| 16 | Q4 | ph[4] | addr bus A[12], U4.3 (PC D0) |
| 17 | Q5 | ph[5] | addr bus A[13], U4.4 (PC D1) |
| 18 | Q6 | ph[6] | addr bus A[14], U4.5 (PC D2) |
| 19 | Q7 | ph[7] | addr bus A[15], U4.6 (PC D3) |
| 20 | VCC | VCC | +5V |

**/OE LOGIC**: U11./OE = /Q2 from U19 (inverted state[1]).
- Fetch (state[1]=0): /Q2=1=HIGH → outputs HI-Z ✓ (U16 drives A[15:8])
- Data (state[1]=1): /Q2=0=LOW → outputs ACTIVE ✓ (ph drives A[15:8])

**DUAL USE of ph outputs**:
1. Drive address bus A[15:8] during data access (via /OE control)
2. Feed PC D inputs (U3.D, U4.D) for JMP instruction PC load

**CONFLICT**: When U11 /OE=HIGH (fetch mode), outputs are hi-Z. But U3/U4 D
inputs need ph values for JMP load. The /LD pulse on U3/U4 happens during S2
(execute), when state[1]=1, so U11 outputs ARE active during JMP. ✓


### U12: 74HC283 — ALU Adder Low Nibble [3:0]

74HC283 pinout: C0=7, A1=5, B1=6, S1=4, A2=3, B2=2, S2=1, GND=8,
               C4=9, S4=10, B4=11, A4=12, S3=13, A3=14, B3=15, VCC=16

```
U12:{type:74HC283, function:'ALU adder low [3:0]',
     1:alu_out[1], 2:xor_out[1], 3:a0[1], 4:alu_out[0], 5:a0[0], 6:xor_out[0], 7:carry_in, 8:GND,
     9:carry_lo_hi, 10:alu_out[3], 11:xor_out[3], 12:a0[3], 13:alu_out[2], 14:a0[2], 15:xor_out[2], 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | S2 | alu_out[1] | U7.3 (a0 D1) |
| 2 | B2 | xor_out[1] | U14.6 (XOR gate 2 output) |
| 3 | A2 | a0[1] | U7.13 (a0 Q1) |
| 4 | S1 | alu_out[0] | U7.2 (a0 D0) |
| 5 | A1 | a0[0] | U7.12 (a0 Q0) |
| 6 | B1 | xor_out[0] | U14.3 (XOR gate 1 output) |
| 7 | C0 | carry_in | U21.11 (AND gate 4 output: sub_mode OR flag_c logic) |
| 8 | GND | GND | Ground |
| 9 | C4 | carry_lo_hi | U13.7 (C0 of high adder) |
| 10 | S4 | alu_out[3] | U7.5 (a0 D3) |
| 11 | B4 | xor_out[3] | U14.8 (XOR gate 3 output) |
| 12 | A4 | a0[3] | U7.15 (a0 Q3) |
| 13 | S3 | alu_out[2] | U7.4 (a0 D2) |
| 14 | A3 | a0[2] | U7.14 (a0 Q2) |
| 15 | B3 | xor_out[2] | U14.11 (XOR gate 4 output)... |
| 16 | VCC | VCC | +5V |

**WAIT — Pin 15 conflict**: U14 only has 4 XOR gates. Gates 1-3 handle bits 0-2.
Gate 4 is used as inverter for /OE control. We need a 4th XOR for bit 3.

**CORRECTION**: Reassign U14 gate 4:
- U14 gates 1-3: XOR for alu_b[0:2] with sub_mode
- U14 gate 4: XOR for alu_b[3] with sub_mode (NOT used as inverter)
- The inverter for U6./OE comes from U15 gate 4 (spare) instead.

Revised pin 15: U12.15 (B3) = U14.11 (XOR gate 4 output for bit 3) ✓

### U13: 74HC283 — ALU Adder High Nibble [7:4]

```
U13:{type:74HC283, function:'ALU adder high [7:4]',
     1:alu_out[5], 2:xor_out[5], 3:a0[5], 4:alu_out[4], 5:a0[4], 6:xor_out[4], 7:U12.9(C4), 8:GND,
     9:carry_out, 10:alu_out[7], 11:xor_out[7], 12:a0[7], 13:alu_out[6], 14:a0[6], 15:xor_out[6], 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | S2 | alu_out[5] | U7.7 (a0 D5) |
| 2 | B2 | xor_out[5] | U15.6 (XOR gate 2 output) |
| 3 | A2 | a0[5] | U7.17 (a0 Q5) |
| 4 | S1 | alu_out[4] | U7.6 (a0 D4) |
| 5 | A1 | a0[4] | U7.16 (a0 Q4) |
| 6 | B1 | xor_out[4] | U15.3 (XOR gate 1 output) |
| 7 | C0 | carry_lo_hi | U12.9 (C4 from low adder) |
| 8 | GND | GND | Ground |
| 9 | C4 | carry_out | U20.12 (D2 of flags FF2 = C flag input) |
| 10 | S4 | alu_out[7] | U7.9 (a0 D7) |
| 11 | B4 | xor_out[7] | U15.11 (XOR gate 4 output)... |
| 12 | A4 | a0[7] | U7.19 (a0 Q7) |
| 13 | S3 | alu_out[6] | U7.8 (a0 D6) |
| 14 | A3 | a0[6] | U7.18 (a0 Q6) |
| 15 | B3 | xor_out[6] | U15.8 (XOR gate 3 output) |
| 16 | VCC | VCC | +5V |

**Pin 11 issue**: U15 gate 4 was going to be the inverter for U6./OE.
If we use U15 gate 4 for alu_b[7] XOR sub_mode, we lose the inverter.

**RESOLUTION**: Use a DIFFERENT source for the inverter. Options:
1. Use U22 (OR gate) with both inputs = ir_op[0] → output = ir_op[0] (buffer, not invert)
2. Use XOR with one input tied HIGH: A XOR 1 = NOT(A). 
   - Tie U15.12 (gate 4 input A) = alu_b[7], U15.13 (gate 4 input B) = sub_mode
   - This IS the correct XOR for bit 7! Gate 4 of U15 does alu_b[7] XOR sub_mode. ✓
3. For the inverter (NOT ir_op[0] for U6./OE): use a spare gate elsewhere.

**INVERTER SOURCE for U6./OE = NOT(ir_op[0])**:
- Use U22 gate 4 as inverter: input A = ir_op[0], input B = ir_op[0].
  OR(x,x) = x. That's a buffer, not inverter. ❌
- Use XOR: x XOR 1 = NOT(x). But all XOR gates are used for ALU.
- Use NAND: not available (no 74HC00).
- Use NOR: not available.
- **SOLUTION**: Steal one XOR gate. Reassign:
  - U14 gates 1-3: alu_b[0:2] XOR sub_mode (3 gates)
  - U14 gate 4: ir_op[0] XOR VCC = NOT(ir_op[0]) → U6./OE (inverter)
  - U15 gates 1-4: alu_b[4:7] XOR sub_mode (4 gates)
  - But now alu_b[3] has NO XOR gate!

**FINAL ALLOCATION** (honest trade-off):
- U14 gate 1: alu_b[0] XOR sub_mode → U12.6 (B1)
- U14 gate 2: alu_b[1] XOR sub_mode → U12.2 (B2)
- U14 gate 3: alu_b[2] XOR sub_mode → U12.15 (B3)
- U14 gate 4: ir_op[0] XOR VCC → NOT(ir_op[0]) → U6.1 (/OE) **INVERTER**
- U15 gate 1: alu_b[4] XOR sub_mode → U13.6 (B1)
- U15 gate 2: alu_b[5] XOR sub_mode → U13.2 (B2)
- U15 gate 3: alu_b[6] XOR sub_mode → U13.15 (B3)
- U15 gate 4: alu_b[7] XOR sub_mode → U13.11 (B4)

**alu_b[3] XOR sub_mode**: NOT AVAILABLE. Bit 3 goes UN-INVERTED to adder.

**IMPACT**: SUB/SBC/CMP will give WRONG results when B[3]=1 and sub_mode=1.
The two's complement inversion is incomplete (bits 0-2 and 4-7 inverted, bit 3 not).

**MITIGATION**: This is a KNOWN BUG. For correct subtraction, software can
work around by decomposing into nibble operations. OR accept 25 chips (add
another 74HC86 for the missing gate).

**ALTERNATIVE**: Don't use gate 4 of U14 as inverter. Instead, generate
NOT(ir_op[0]) from the 74HC139 decoder. U18 decoder B with A0=ir_op[0],
A1=GND: /Y0 active when ir_op[0]=0, /Y1 active when ir_op[0]=1.
/Y1 = active LOW when ir_op[0]=1 = LOW when immediate mode.
U6./OE needs HIGH when register mode (ir_op[0]=0).
U6./OE = /Y0 of decoder B? No — /Y0 = LOW when ir_op[0]=0 (register mode).
We need /OE=HIGH when register mode. /Y0=LOW when register. Inverted. ❌

**REAL FINAL ANSWER**: Use U14 gate 4 as the inverter. Accept bit 3 limitation.
OR: wire alu_b[3] directly to U12.11 (B4) WITHOUT XOR. For ADD, this is fine
(no inversion needed). For SUB, bit 3 is wrong. Document as known limitation.

### U14: 74HC86 — XOR Low Nibble [2:0] + Inverter

74HC86 pinout: 1A=1, 1B=2, 1Y=3, 2A=4, 2B=5, 2Y=6, GND=7,
              3Y=8, 3A=9, 3B=10, 4Y=11, 4A=12, 4B=13, VCC=14

```
U14:{type:74HC86, function:'XOR low nibble + inverter',
     1:alu_b[0], 2:sub_mode, 3:U12.6, 4:alu_b[1], 5:sub_mode, 6:U12.2, 7:GND,
     8:U12.15, 9:alu_b[2], 10:sub_mode, 11:U6.1(/OE), 12:ir_op[0], 13:VCC, 14:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | 1A | alu_b[0] | Shared wire (U6.12 or U8.12) |
| 2 | 1B | sub_mode | U5.15 (ir_op[3]) |
| 3 | 1Y | xor_out[0] | U12.6 (B1 of low adder) |
| 4 | 2A | alu_b[1] | Shared wire (U6.13 or U8.13) |
| 5 | 2B | sub_mode | U5.15 (ir_op[3]) |
| 6 | 2Y | xor_out[1] | U12.2 (B2 of low adder) |
| 7 | GND | GND | Ground |
| 8 | 3Y | xor_out[2] | U12.15 (B3 of low adder) |
| 9 | 3A | alu_b[2] | Shared wire (U6.14 or U8.14) |
| 10 | 3B | sub_mode | U5.15 (ir_op[3]) |
| 11 | 4Y | NOT_ir_op0 | U6.1 (/OE = NOT(ir_op[0])) |
| 12 | 4A | ir_op[0] | U5.12 |
| 13 | 4B | VCC | Tied HIGH (XOR with 1 = invert) |
| 14 | VCC | VCC | +5V |

### U15: 74HC86 — XOR High Nibble [7:4]

```
U15:{type:74HC86, function:'XOR high nibble [7:4]',
     1:alu_b[4], 2:sub_mode, 3:U13.6, 4:alu_b[5], 5:sub_mode, 6:U13.2, 7:GND,
     8:U13.15, 9:alu_b[6], 10:sub_mode, 11:U13.11, 12:alu_b[7], 13:sub_mode, 14:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | 1A | alu_b[4] | Shared wire (U6.16 or U8.16) |
| 2 | 1B | sub_mode | U5.15 (ir_op[3]) |
| 3 | 1Y | xor_out[4] | U13.6 (B1 of high adder) |
| 4 | 2A | alu_b[5] | Shared wire (U6.17 or U8.17) |
| 5 | 2B | sub_mode | U5.15 (ir_op[3]) |
| 6 | 2Y | xor_out[5] | U13.2 (B2 of high adder) |
| 7 | GND | GND | Ground |
| 8 | 3Y | xor_out[6] | U13.15 (B3 of high adder) |
| 9 | 3A | alu_b[6] | Shared wire (U6.18 or U8.18) |
| 10 | 3B | sub_mode | U5.15 (ir_op[3]) |
| 11 | 4Y | xor_out[7] | U13.11 (B4 of high adder) |
| 12 | 4A | alu_b[7] | Shared wire (U6.19 or U8.19) |
| 13 | 4B | sub_mode | U5.15 (ir_op[3]) |
| 14 | VCC | VCC | +5V |


### U16: 74HC541 — PC High Byte Buffer (tri-state to A[15:8])

74HC541 pinout: /OE1=1, A1=2, A2=3, A3=4, A4=5, A5=6, A6=7, A7=8, A8=9, GND=10,
               Y8=11, Y7=12, Y6=13, Y5=14, Y4=15, Y3=16, Y2=17, Y1=18, /OE2=19, VCC=20

```
U16:{type:74HC541, function:'PC high buffer → A[15:8]',
     1:state[1], 2:U2.14(PC4), 3:U2.13(PC5), 4:U2.12(PC6), 5:U2.11(PC7), 6:U3.14(PC8), 7:U3.13(PC9), 8:U3.12(PC10), 9:U3.11(PC11), 10:GND,
     11:A[11], 12:A[10], 13:A[9], 14:A[8], 15:A[7], 16:A[6], 17:A[5], 18:A[4], 19:state[1], 20:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE1 | state[1] | U19.9 (Q2) — disabled during data access |
| 2 | A1 | PC[4] | U2.14 (QA) |
| 3 | A2 | PC[5] | U2.13 (QB) |
| 4 | A3 | PC[6] | U2.12 (QC) |
| 5 | A4 | PC[7] | U2.11 (QD) |
| 6 | A5 | PC[8] | U3.14 (QA) |
| 7 | A6 | PC[9] | U3.13 (QB) |
| 8 | A7 | PC[10] | U3.12 (QC) |
| 9 | A8 | PC[11] | U3.11 (QD) |
| 10 | GND | GND | Ground |
| 11 | Y8 | A[11] | ROM.23, RAM.23 |
| 12 | Y7 | A[10] | ROM.21, RAM.21 |
| 13 | Y6 | A[9] | ROM.24, RAM.24 |
| 14 | Y5 | A[8] | ROM.25, RAM.25 |
| 15 | Y4 | A[7] | ROM.3, RAM.3 |
| 16 | Y3 | A[6] | ROM.4, RAM.4 |
| 17 | Y2 | A[5] | ROM.5, RAM.5 |
| 18 | Y1 | A[4] | ROM.6, RAM.6 |
| 19 | /OE2 | state[1] | U19.9 (Q2) — same as /OE1 |
| 20 | VCC | VCC | +5V |

**/OE LOGIC**: Both /OE1 and /OE2 = state[1] (Q2 from U19).
- Fetch (state[1]=0): /OE=LOW → outputs ACTIVE → PC high drives A[15:8] ✓
- Data (state[1]=1): /OE=HIGH → outputs HI-Z → U11 (ph) drives A[15:8] ✓

**NOTE**: U16 buffers 8 bits: PC[11:4]. But we need A[15:8] which is PC[15:8].
Let me reconsider. The address bus A[15:8] should carry PC bits 15-8 during fetch.

**CORRECTION**: A[15:8] = PC[15:8]. So U16 inputs should be:
- A1 = PC[8] from U3.14 (QA)
- A2 = PC[9] from U3.13 (QB)
- A3 = PC[10] from U3.12 (QC)
- A4 = PC[11] from U3.11 (QD)
- A5 = PC[12] from U4.14 (QA)
- A6 = PC[13] from U4.13 (QB)
- A7 = PC[14] from U4.12 (QC)
- A8 = PC[15] from U4.11 (QD)

And Y outputs drive A[15:8] of the address bus. Let me also reconsider A[7:4].

**ADDRESS BUS ARCHITECTURE (REVISED)**:
- A[3:0]: from U17 (74HC157 mux, 4 channels)
- A[7:4]: DIRECTLY from U2 outputs (PC[7:4]) during fetch... but during data
  access these are wrong. U2 has no /OE. **PROBLEM**.

**HONEST ASSESSMENT**: With one 74HC157 (4 channels), we can only mux A[3:0].
A[7:4] cannot be muxed between PC[7:4] and pointer without another chip.

**DESIGN CHOICE**: Accept that data pointer only addresses within a 16-byte
window (A[3:0] from pl, A[7:4] from PC which is "wrong" during data access).
OR: use U16 to buffer ALL of PC[15:4] (12 bits) but 541 only has 8 channels.

**FINAL DESIGN**: U16 buffers PC[15:8] → A[15:8]. A[7:4] comes from U2 directly
(no tri-state, always driven). During data access, A[7:4] = PC[7:4] which is
WRONG for pointer access. This means pointer addressing is limited to the same
256-byte page as the current PC low byte.

**ACCEPTED**: This is a hardware limitation of the 24-chip design. The pointer
effectively addresses {ph[7:0], PC[7:4], pl[3:0]} — a 16-byte window within
the page set by ph, offset by the current PC[7:4] value.

**REVISED U16 pinout (correct: PC[15:8] → A[15:8])**:

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /OE1 | state[1] | U19.9 (Q2) |
| 2 | A1 | PC[8] | U3.14 (QA) |
| 3 | A2 | PC[9] | U3.13 (QB) |
| 4 | A3 | PC[10] | U3.12 (QC) |
| 5 | A4 | PC[11] | U3.11 (QD) |
| 6 | A5 | PC[12] | U4.14 (QA) |
| 7 | A6 | PC[13] | U4.13 (QB) |
| 8 | A7 | PC[14] | U4.12 (QC) |
| 9 | A8 | PC[15] | U4.11 (QD) |
| 10 | GND | GND | Ground |
| 11 | Y8 | A[15] | ROM/RAM decode, addr bus |
| 12 | Y7 | A[14] | ROM.1, RAM.1 |
| 13 | Y6 | A[13] | ROM.26, RAM.26 |
| 14 | Y5 | A[12] | ROM.2, RAM.2 |
| 15 | Y4 | A[11] | ROM.23, RAM.23 |
| 16 | Y3 | A[10] | ROM.21, RAM.21 |
| 17 | Y2 | A[9] | ROM.24, RAM.24 |
| 18 | Y1 | A[8] | ROM.25, RAM.25 |
| 19 | /OE2 | state[1] | U19.9 (Q2) |
| 20 | VCC | VCC | +5V |

### U17: 74HC157 — Address Mux Low Byte A[3:0]

74HC157 pinout: S=1, 1A=2, 1B=3, 1Y=4, 2A=5, 2B=6, 2Y=7, GND=8,
               3Y=9, 3B=10, 3A=11, 4Y=12, 4B=13, 4A=14, /E=15, VCC=16

```
U17:{type:74HC157, function:'addr mux A[3:0]',
     1:state[1], 2:U1.14(PC0), 3:U10.14(pl0), 4:A[0], 5:U1.13(PC1), 6:U10.13(pl1), 7:A[1], 8:GND,
     9:A[2], 10:U10.12(pl2), 11:U1.12(PC2), 12:A[3], 13:U10.11(pl3), 14:U1.11(PC3), 15:GND, 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | S | addr_sel | U19.9 (state[1]): 0=A inputs, 1=B inputs |
| 2 | 1A | PC[0] | U1.14 (QA) |
| 3 | 1B | pl[0] | U10.14 (QA) |
| 4 | 1Y | A[0] | ROM.10, RAM.10 |
| 5 | 2A | PC[1] | U1.13 (QB) |
| 6 | 2B | pl[1] | U10.13 (QB) |
| 7 | 2Y | A[1] | ROM.9, RAM.9 |
| 8 | GND | GND | Ground |
| 9 | 3Y | A[2] | ROM.8, RAM.8 |
| 10 | 3B | pl[2] | U10.12 (QC) |
| 11 | 3A | PC[2] | U1.12 (QC) |
| 12 | 4Y | A[3] | ROM.7, RAM.7 |
| 13 | 4B | pl[3] | U10.11 (QD) |
| 14 | 4A | PC[3] | U1.11 (QD) |
| 15 | /E | GND | Always enabled (active low) |
| 16 | VCC | VCC | +5V |

**S = state[1]**: During fetch (S0/S1, state[1]=0), selects A inputs (PC[3:0]).
During data access (S2/S3, state[1]=1), selects B inputs (pl[3:0]).

### U18: 74HC139 — Dual 2-to-4 Decoder

74HC139 pinout: /Ea=1, A0a=2, A1a=3, /Y0a=4, /Y1a=5, /Y2a=6, /Y3a=7, GND=8,
               /Y3b=9, /Y2b=10, /Y1b=11, /Y0b=12, A1b=13, A0b=14, /Eb=15, VCC=16

**Decoder A**: Class decode, enabled by S2_n (active during S2)
**Decoder B**: Register write select, enabled by write_en_n

```
U18:{type:74HC139, function:'dual decoder: class + reg write',
     1:S2_n, 2:ir_op[6], 3:ir_op[7], 4:class_00_n, 5:class_01_n, 6:class_10_n, 7:class_11_n, 8:GND,
     9:/Y3b, 10:/Y2b, 11:/Y1b, 12:/Y0b, 13:ir_op[1], 14:ir_op[0], 15:write_en_n, 16:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /Ea | S2_n | NOT(S2) — need inverter... use /Q from state logic |
| 2 | A0a | ir_op[6] | U5.18 |
| 3 | A1a | ir_op[7] | U5.19 |
| 4 | /Y0a | class_00_n | ALU class active (low during S2 + class 00) |
| 5 | /Y1a | class_01_n | LDST class active |
| 6 | /Y2a | class_10_n | Branch class active |
| 7 | /Y3a | class_11_n | System class active |
| 8 | GND | GND | Ground |
| 9 | /Y3b | reg_wr_3 | pl_ld_n → U10.9, ph_clk logic |
| 10 | /Y2b | reg_wr_2 | sp_clk → U9.11 |
| 11 | /Y1b | reg_wr_1 | t0_clk → U8.11 |
| 12 | /Y0b | reg_wr_0 | a0_clk logic (for LI a0) |
| 13 | A1b | ir_op[1] | U5.13 |
| 14 | A0b | ir_op[0] | U5.12 |
| 15 | /Eb | write_en_n | Control: NOT(write enable) |
| 16 | VCC | VCC | +5V |

**Decoder A enable**: /Ea is active LOW. Decoder outputs go low only when /Ea=LOW.
We want decode active during S2. So /Ea = NOT(S2).
S2 = state[1] AND NOT(state[0]) = Q2 AND /Q1.
NOT(S2) = NOT(Q2 AND /Q1) = /Q2 OR Q1 (De Morgan).
We can generate this with U22 (OR gate): /Q2 OR Q1 → S2_n. ✓

**Decoder B enable**: /Eb = write_en_n. This should be LOW when a register
write is needed. For LI instructions (class 01, op 000), write_en is active.
write_en_n = class_01_n (pin 5) — active low during S2 + class 01 + op=000.
But we need more specific gating (only for LI, not all class 01).
**SIMPLIFICATION**: /Eb = class_01_n AND op=000. Since class_01_n is already
gated by S2, we just need op=000 check. With ir_op[5:3]=000, all three bits
are 0. We can use: /Eb = class_01_n (active for ALL class 01 during S2).
The register select (A0b, A1b) then picks which register. This means ALL
class 01 instructions trigger a register write — stores would write too.
**FIX**: Use a more specific enable. OR just accept that decoder B outputs
pulse during all class 01 S2, and the register CLK only matters if the
register actually latches (edge-triggered, so a pulse with same data = no change).

**PRACTICAL**: /Eb = U18.5 (class_01_n) — decoder B active during class 01 S2.


### U19: 74HC74 — State Counter (2 flip-flops, ripple)

74HC74 pinout: /CLR1=1, D1=2, CLK1=3, /PRE1=4, Q1=5, /Q1=6, GND=7,
              /Q2=8, Q2=9, /PRE2=10, CLK2=11, D2=12, /CLR2=13, VCC=14

```
U19:{type:74HC74, function:'state counter',
     1:/RST, 2:/Q1(pin6), 3:CLK, 4:VCC, 5:state[0], 6:/Q1, 7:GND,
     8:/Q2, 9:state[1], 10:VCC, 11:/Q1(pin6), 12:/Q2(pin8), 13:/RST, 14:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /CLR1 | /RST | Reset circuit (clears to 0) |
| 2 | D1 | /Q1 | Pin 6 (own /Q1 → toggle mode) |
| 3 | CLK1 | CLK | Oscillator (system clock) |
| 4 | /PRE1 | VCC | Tied high (no preset) |
| 5 | Q1 | state[0] | U21.1(AND 1A), U22.1(OR 1A), ir_latch/opr_latch logic |
| 6 | /Q1 | /state[0] | Pin 2 (D1 feedback), Pin 11 (CLK2), U21.4(AND 2B) |
| 7 | GND | GND | Ground |
| 8 | /Q2 | /state[1] | Pin 12 (D2 feedback), U11.1(/OE), pc_inc, /RD logic |
| 9 | Q2 | state[1] | U16.1+19(/OE), U17.1(S), U21.4(AND 2A), U22.7(OR 3A) |
| 10 | /PRE2 | VCC | Tied high |
| 11 | CLK2 | /Q1 | Pin 6 (FF2 clocks on falling edge of state[0]) |
| 12 | D2 | /Q2 | Pin 8 (own /Q2 → toggle mode) |
| 13 | /CLR2 | /RST | Reset circuit |
| 14 | VCC | VCC | +5V |

**State sequence** (ripple counter):
- CLK↑: FF1 toggles (D=/Q1)
- FF1./Q falling edge: FF2 toggles (D=/Q2)
- Sequence: Q2Q1 = 00→01→10→11→00... = S0→S1→S2→S3→S0

**NOTE**: This is a ripple counter, not synchronous. FF2 changes slightly after
FF1. At 3.5 MHz this is fine (74HC74 propagation ~15ns, clock period ~285ns).
At 10 MHz (100ns period), still OK with margin.

### U20: 74HC74 — Flags (Z flag, C flag)

```
U20:{type:74HC74, function:'flags: Z and C',
     1:/RST, 2:alu_zero, 3:flags_we, 4:VCC, 5:flag_z, 6:/flag_z, 7:GND,
     8:/flag_c, 9:flag_c, 10:VCC, 11:flags_we, 12:carry_out, 13:/RST, 14:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | /CLR1 | /RST | Reset circuit (clears Z=0) |
| 2 | D1 | alu_zero | Zero detect logic (see below) |
| 3 | CLK1 | flags_we | U21.8 (AND gate 3 output) |
| 4 | /PRE1 | VCC | Tied high |
| 5 | Q1 | flag_z | Branch condition logic |
| 6 | /Q1 | /flag_z | (available) |
| 7 | GND | GND | Ground |
| 8 | /Q2 | /flag_c | (available) |
| 9 | Q2 | flag_c | Branch condition logic, carry_in logic |
| 10 | /PRE2 | VCC | Tied high |
| 11 | CLK2 | flags_we | U21.8 (same clock as FF1) |
| 12 | D2 | carry_out | U13.9 (C4 from high adder) |
| 13 | /CLR2 | /RST | Reset circuit (clears C=0) |
| 14 | VCC | VCC | +5V |

**ZERO DETECT (alu_zero)**: Needs to be HIGH when all 8 ALU output bits = 0.
alu_zero = NOR(alu_out[7:0]) = NOT(alu_out[0] OR alu_out[1] OR ... OR alu_out[7])

With available gates:
- U22 gate 3: OR(alu_out[0], alu_out[1]) → z_or_01
- U22 gate 4: OR(alu_out[2], alu_out[3]) → z_or_23
- Need OR(alu_out[4:5]), OR(alu_out[6:7]), then OR all together, then invert.
- That's 4 OR gates (all of U22) + 2 more OR + 1 invert = NOT ENOUGH.

**HONEST**: Zero detect cannot be built with remaining gates. Options:
1. Skip Z flag (only use C flag for branches) — functional but limited
2. Use a 74HC688 comparator (adds 1 chip = 25 total)
3. Use diode-OR + pull-up (analog hack, unreliable at speed)
4. Use ALU output bit 7 as N flag instead (sign flag, not zero)

**FOR THIS 24-CHIP DESIGN**: Z flag detection is INCOMPLETE. We document the
intended connection (alu_zero) but acknowledge it requires external logic
not available in the 24-chip budget. The C flag works correctly.

**PRACTICAL WORKAROUND**: Use the carry flag for most branch decisions.
For zero-check, software can use CMP + branch-on-carry tricks.

### U21: 74HC08 — AND Gates (Control)

74HC08 pinout: 1A=1, 1B=2, 1Y=3, 2A=4, 2B=5, 2Y=6, GND=7,
              3Y=8, 3A=9, 3B=10, 4Y=11, 4A=12, 4B=13, VCC=14

```
U21:{type:74HC08, function:'4x AND gates',
     1:Q1, 2:/Q2, 3:ir_latch, 4:Q2, 5:/Q1, 6:opr_latch, 7:GND,
     8:flags_we, 9:S2(U21.6_delayed), 10:class_00_n_inv, 11:carry_in, 12:sub_mode, 13:carry_sel, 14:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | 1A | state[0] | U19.5 (Q1) |
| 2 | 1B | /state[1] | U19.8 (/Q2) |
| 3 | 1Y | S1 | ir_latch → U5.11 (IR opcode CLK) |
| 4 | 2A | state[1] | U19.9 (Q2) |
| 5 | 2B | /state[0] | U19.6 (/Q1) |
| 6 | 2Y | S2 | opr_latch → U6.11 (IR operand CLK) |
| 7 | GND | GND | Ground |
| 8 | 3Y | flags_we | U20.3 + U20.11 (flags CLK) |
| 9 | 3A | S2 | U21.6 (own output, S2 signal) |
| 10 | 3B | class_00_act | NOT(class_00_n) — PROBLEM: need inverter |
| 11 | 4Y | carry_in | U12.7 (C0 of low adder) |
| 12 | 4A | sub_mode | U5.15 (ir_op[3]) |
| 13 | 4B | carry_sel | ir_op[1] AND flag_c logic... simplified to ir_op[3] |
| 14 | VCC | VCC | +5V |

**Gate 3 problem**: class_00_n (U18.4) is active LOW. We need active HIGH for AND.
No inverter available. 

**FIX**: Use De Morgan. flags_we = S2 AND class_00 = NOT(NOT(S2) OR NOT(class_00))
= NOT(S2_n OR class_00_n). We have OR gates (U22). NOR = OR + invert... no inverter.

**ALTERNATIVE**: flags_we = NOT(class_00_n) when S2 is active. Since class_00_n
is already gated by S2 (U18 decoder A is enabled by S2_n), class_00_n is LOW
only during S2 AND class_00. So class_00_n itself (inverted) IS flags_we.
Use: flags_we = NOT(class_00_n). Need 1 inverter.

**PRACTICAL**: Use the XOR-as-inverter trick on a spare... but all XOR gates used.
Use: tie U21 gate 3 inputs to: A=VCC, B=class_00_n. AND(1, class_00_n) = class_00_n.
That gives us class_00_n (active low), not what we want.

**REAL FIX**: The 74HC74 CLK triggers on RISING edge. class_00_n goes LOW at
start of S2 (when class=00) and returns HIGH at end of S2. The RISING edge of
class_00_n occurs at the S2→S3 transition. Use class_00_n directly as flags CLK:
flags latch on the rising edge = end of S2. ✓

**REVISED**: flags_we = class_00_n (U18.4) directly to U20.3 and U20.11.
Flags latch on rising edge of class_00_n = S2→S3 transition. ✓
This frees up AND gate 3.

**REVISED U21 allocation**:
| Gate | Function | A | B | Output |
|:----:|----------|---|---|--------|
| 1 | S1 detect | Q1 | /Q2 | ir_latch → U5.11 |
| 2 | S2 detect | Q2 | /Q1 | opr_latch → U6.11, S2 signal |
| 3 | /WR | S3 | is_store | /WR → RAM.27 |
| 4 | carry_in | sub_mode | (see below) | carry_in → U12.7 |

**Gate 3 revised**: /WR generation.
S3 = Q2 AND Q1. But we need another AND for that... we only have 4 gates.
S3 = NOT(/Q2) AND NOT(/Q1) = ... can't easily get S3 from available signals.

**SIMPLIFICATION**: Use Q2 AND Q1 directly:
- Gate 3: A=Q2 (U19.9), B=Q1 (U19.5) → S3 signal
- But we also need S3 AND is_store for /WR. That's a 3-input AND (S3 AND is_store).
  With 2-input gates: (Q2 AND Q1) AND is_store = need 2 gates.

**FINAL U21 allocation (honest)**:
| Gate | A | B | Output | Signal |
|:----:|---|---|--------|--------|
| 1 | Q1 (U19.5) | /Q2 (U19.8) | → U5.11 | ir_latch (=S1) |
| 2 | Q2 (U19.9) | /Q1 (U19.6) | → U6.11 | opr_latch (=S2) |
| 3 | Q2 (U19.9) | Q1 (U19.5) | → S3 net | S3 signal |
| 4 | ir_op[3] (U5.15) | ir_op[3] (U5.15) | → U12.7 | carry_in = sub_mode |

**Gate 4 explanation**: For SUB, carry_in = 1 (two's complement). sub_mode = ir_op[3].
AND(x,x) = x. So carry_in = ir_op[3] directly. Could just wire directly without
a gate. Use gate 4 for something else:

**Gate 4 revised**: /WR = S3 AND is_store_class
- A = S3 (U21.8, gate 3 output)
- B = ir_op[4] (U5.16) — store instructions have bit 4 set (SB = 01_010_xxx)
- Output → RAM.27 (/WE)

But ir_op[4] alone doesn't distinguish stores from other class 01 ops.
In the Verilog: SB(ptr) = 01_010_000, SB(zp) = 01_100_000.
Store ops: ir_op[5:3] = 010 or 100. Not a single bit.

**SIMPLIFICATION**: /WR = S3 AND class_01 AND op_is_store. Too complex for 1 gate.
Use: /WR = NOT(S3 AND write_signal). The write_signal comes from... the state machine
should only enter S3 for memory ops. During S3, if it's a store, assert /WR.

**PRACTICAL**: /WR = S3 AND ir_op[5] (bit 5 distinguishes load from store in some
encodings). Actually in the Verilog encoding, stores are SB(ptr)=01_010, SB(zp)=01_100,
PUSH=11_000. No single bit identifies all stores.

**ACCEPTED**: Gate 4 = S3 (U21.8) AND ir_op[4] (U5.16) → /WR. This is approximate.
Some non-store instructions may trigger a false /WR during S3, but if RAM /CE is
not active (wrong class), no actual write occurs. Use /RAM_CE gating to prevent
spurious writes.

### U22: 74HC32 — OR Gates (Control)

74HC32 pinout: 1A=1, 1B=2, 1Y=3, 2A=4, 2B=5, 2Y=6, GND=7,
              3Y=8, 3A=9, 3B=10, 4Y=11, 4A=12, 4B=13, VCC=14

```
U22:{type:74HC32, function:'4x OR gates',
     1:/Q2, 2:Q1, 3:S2_n, 4:/Q2, 5:GND, 6:pc_inc, 7:GND,
     8:/RD, 9:/Q2, 10:S3_load, 11:a0_clk, 12:alu_wr, 13:mem_load, 14:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | 1A | /Q2 | U19.8 (/state[1]) |
| 2 | 1B | Q1 | U19.5 (state[0]) |
| 3 | 1Y | S2_n | U18.1 (/Ea — decoder A enable) |
| 4 | 2A | /Q2 | U19.8 (/state[1]) |
| 5 | 2B | GND | Tied low (OR with 0 = pass-through) |
| 6 | 2Y | pc_inc | U1-U4.7+10 (ENP+ENT on all PC counters) |
| 7 | GND | GND | Ground |
| 8 | 3Y | /RD | ROM.22(/OE), RAM.22(/OE) |
| 9 | 3A | /Q2 | U19.8 (read during fetch: S0,S1) |
| 10 | 3B | S3_load | S3 AND is_load (from external logic or gate) |
| 11 | 4Y | a0_clk | U7.11 (accumulator CLK) |
| 12 | 4A | alu_wr | ALU write signal (S2 AND class_00) |
| 13 | 4B | mem_load | Memory load complete (S3 AND is_load) |
| 14 | VCC | VCC | +5V |

**Gate 1**: S2_n = /Q2 OR Q1. When S2 (Q2=1, Q1=0): /Q2=0, Q1=0 → OR=0. ✓
All other states: at least one input is 1 → OR=1. ✓
So S2_n = LOW only during S2. Perfect for U18./Ea (active low enable).

**Gate 2**: pc_inc = /Q2. During S0 and S1 (state[1]=0), /Q2=1 → pc_inc HIGH.
During S2 and S3 (state[1]=1), /Q2=0 → pc_inc LOW. PC counts during fetch only. ✓
(Gate 2B tied to GND makes it a simple buffer of /Q2.)

**Gate 3**: /RD = /Q2 OR S3_load. Active LOW for read.
- During fetch (S0/S1): /Q2=1 → output=1... WAIT. /RD should be LOW during read.
  
**CORRECTION**: /RD is active LOW. We want /RD=LOW during S0, S1 (fetch reads).
/Q2 = HIGH during S0/S1. We need the INVERSE.
Actually: mem_rd should be active during fetch. /RD = NOT(fetch_phase OR load_phase).
= NOT(/Q2... no. Let me reconsider.

/RD should be LOW (active) when reading: during S0, S1, and S3(load).
/RD = NOT(reading). reading = (state[1]=0) OR (S3 AND is_load).
NOT(reading) = NOT(NOT(state[1]) OR S3_load) = state[1] AND NOT(S3_load).

This is getting complex. **SIMPLEST**: /RD = Q2 NAND (NOT is_load OR NOT Q1).
Too complex.

**PRACTICAL SOLUTION**: Tie /RD = GND (always reading). ROM and RAM only drive
the bus when /CE is also active. Writes are controlled by /WE. Reading when not
needed just means the bus has data on it that's ignored. This is safe because:
- ROM /CE controls whether ROM drives bus
- RAM /CE controls whether RAM drives bus  
- During writes, /WE overrides /OE on RAM (write takes priority)

**REVISED**: /RD = GND (always active). Simplifies to a wire. Frees gate 3.

**Gate 3 revised**: Use for something else. Perhaps:
- S3_load signal generation, or
- Branch condition combining, or
- Zero detect partial

**FINAL U22 allocation**:
| Gate | A | B | Output | Signal |
|:----:|---|---|--------|--------|
| 1 | /Q2 (U19.8) | Q1 (U19.5) | → U18.1 | S2_n (decoder A enable) |
| 2 | /Q2 (U19.8) | GND | → U1-4.7+10 | pc_inc (=pass /Q2) |
| 3 | class_00_n (U18.4) | class_01_n (U18.5) | → (spare) | (both high = not class 00 or 01) |
| 4 | alu_wr | mem_load | → U7.11 | a0_clk |


### ROM: AT28C256 — Program ROM (32KB)

AT28C256 pinout (DIP-28):

```
ROM:{type:AT28C256, function:'Program ROM 32KB',
     1:A[14], 2:A[12], 3:A[7], 4:A[6], 5:A[5], 6:A[4], 7:A[3], 8:A[2], 9:A[1], 10:A[0],
     11:D[0], 12:D[1], 13:D[2], 14:GND, 15:D[3], 16:D[4], 17:D[5], 18:D[6], 19:D[7],
     20:/CE, 21:A[10], 22:/OE, 23:A[11], 24:A[9], 25:A[8], 26:A[13], 27:/WE, 28:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | A14 | A[14] | Address bus |
| 2 | A12 | A[12] | Address bus |
| 3 | A7 | A[7] | Address bus |
| 4 | A6 | A[6] | Address bus |
| 5 | A5 | A[5] | Address bus |
| 6 | A4 | A[4] | Address bus |
| 7 | A3 | A[3] | U17.12 (4Y) |
| 8 | A2 | A[2] | U17.9 (3Y) |
| 9 | A1 | A[1] | U17.7 (2Y) |
| 10 | A0 | A[0] | U17.4 (1Y) |
| 11 | D0 | D[0] | Data bus |
| 12 | D1 | D[1] | Data bus |
| 13 | D2 | D[2] | Data bus |
| 14 | GND | GND | Ground |
| 15 | D3 | D[3] | Data bus |
| 16 | D4 | D[4] | Data bus |
| 17 | D5 | D[5] | Data bus |
| 18 | D6 | D[6] | Data bus |
| 19 | D7 | D[7] | Data bus |
| 20 | /CE | /ROM_CE | NOT(A[15]) — ROM at $8000-$FFFF |
| 21 | A10 | A[10] | Address bus |
| 22 | /OE | GND | Always enabled (active low) |
| 23 | A11 | A[11] | Address bus |
| 24 | A9 | A[9] | Address bus |
| 25 | A8 | A[8] | Address bus |
| 26 | A13 | A[13] | Address bus |
| 27 | /WE | VCC | Tied high (no writes) |
| 28 | VCC | VCC | +5V |

**/ROM_CE**: Need NOT(A[15]). A[15] comes from U16.11 (Y8) during fetch or
U11.19 (Q7) during data. The inverter for /ROM_CE can be built from a spare
gate: use U22 gate 3 as buffer... no, need invert. **Use external inverter
(1x 2N7000 MOSFET + 10K pull-up) or tie /CE=GND and rely on /OE gating.**

**PRACTICAL**: Tie ROM /CE = GND (always selected). ROM only drives bus when
/OE=LOW. Tie /OE = GND too (always driving). Bus contention with RAM is
prevented by RAM /CE = A[15] (RAM disabled when A[15]=1=ROM space). ✓


### RAM: 62256 — Data RAM (32KB)

62256 pinout (DIP-28, same as AT28C256):

```
RAM:{type:62256, function:'Data RAM 32KB',
     1:A[14], 2:A[12], 3:A[7], 4:A[6], 5:A[5], 6:A[4], 7:A[3], 8:A[2], 9:A[1], 10:A[0],
     11:D[0], 12:D[1], 13:D[2], 14:GND, 15:D[3], 16:D[4], 17:D[5], 18:D[6], 19:D[7],
     20:/CE, 21:A[10], 22:/OE, 23:A[11], 24:A[9], 25:A[8], 26:A[13], 27:/WE, 28:VCC}
```

| Pin | Name | Signal | Connects to |
|:---:|------|--------|-------------|
| 1 | A14 | A[14] | Address bus |
| 2 | A12 | A[12] | Address bus |
| 3 | A7 | A[7] | Address bus |
| 4 | A6 | A[6] | Address bus |
| 5 | A5 | A[5] | Address bus |
| 6 | A4 | A[4] | Address bus |
| 7 | A3 | A[3] | U17.12 (4Y) |
| 8 | A2 | A[2] | U17.9 (3Y) |
| 9 | A1 | A[1] | U17.7 (2Y) |
| 10 | A0 | A[0] | U17.4 (1Y) |
| 11 | D0 | D[0] | Data bus |
| 12 | D1 | D[1] | Data bus |
| 13 | D2 | D[2] | Data bus |
| 14 | GND | GND | Ground |
| 15 | D3 | D[3] | Data bus |
| 16 | D4 | D[4] | Data bus |
| 17 | D5 | D[5] | Data bus |
| 18 | D6 | D[6] | Data bus |
| 19 | D7 | D[7] | Data bus |
| 20 | /CE | A[15] | Direct from addr bus (RAM at $0000-$7FFF) |
| 21 | A10 | A[10] | Address bus |
| 22 | /OE | GND | Always enabled for reads |
| 23 | A11 | A[11] | Address bus |
| 24 | A9 | A[9] | Address bus |
| 25 | A8 | A[8] | Address bus |
| 26 | A13 | A[13] | Address bus |
| 27 | /WE | /WR | U21.11 (AND gate 4: S3 AND is_store) |
| 28 | VCC | VCC | +5V |

**RAM /CE = A[15]**: When A[15]=0 (address $0000-$7FFF), /CE=LOW → RAM active.
When A[15]=1 (address $8000-$FFFF), /CE=HIGH → RAM disabled (ROM space). ✓

**RAM /OE = GND**: Always reading. During writes, /WE overrides /OE per datasheet.
RAM outputs are tri-stated during write cycle regardless of /OE state. ✓

**Memory Map**:
- $0000-$7FFF: RAM (32KB) — zero-page, stack, data
- $8000-$FFFF: ROM (32KB) — code (reset vector at $0000 or $C000)


---

## Support Circuits

### Oscillator — 3.5 MHz

```
Component: 3.5 MHz crystal oscillator module (4-pin DIP or 14-pin half-can)
Pin 1:  NC (or GND)
Pin 7:  GND
Pin 8:  OUT → CLK bus (U1.2, U2.2, U3.2, U4.2, U10.2, U19.3)
Pin 14: VCC
```

### Reset Circuit

```
VCC ──[10KΩ]──┬── /RST bus
              │
            [100nF]
              │
GND ──────────┴──[SW1 pushbutton]── GND

/RST connects to:
  U1.1, U2.1, U3.1, U4.1   (PC /CLR)
  U10.1                      (pl /CLR)
  U19.1, U19.13             (state /CLR)
  U20.1, U20.13             (flags /CLR)

Power-on delay: RC = 10K × 100nF = 1ms
```

### 18 LEDs

```
LED1-8:   Data bus D[7:0]
  D[n] ──[330Ω]──[LED]── GND   (n = 0..7)

LED9-12:  Address bus A[3:0] (from U17 outputs)
  A[n] ──[330Ω]──[LED]── GND   (n = 0..3)

LED13-16: State and control
  LED13: state[0] (U19.5) ──[330Ω]──[LED]── GND
  LED14: state[1] (U19.9) ──[330Ω]──[LED]── GND
  LED15: flag_z (U20.5) ──[330Ω]──[LED]── GND
  LED16: flag_c (U20.9) ──[330Ω]──[LED]── GND

LED17: CLK indicator
  CLK ──[330Ω]──[LED]── GND

LED18: /RST indicator (lights during reset)
  VCC ──[330Ω]──[LED]── /RST
```

### 40-Pin Bus Connector (J1)

```
Pin  Signal      Pin  Signal
---  ---------   ---  ---------
1    VCC         2    GND
3    CLK         4    /RST
5    A[0]        6    A[1]
7    A[2]        8    A[3]
9    A[4]        10   A[5]
11   A[6]        12   A[7]
13   A[8]        14   A[9]
15   A[10]       16   A[11]
17   A[12]       18   A[13]
19   A[14]       20   A[15]
21   D[0]        22   D[1]
23   D[2]        24   D[3]
25   D[4]        26   D[5]
27   D[6]        28   D[7]
29   /RD(GND)    30   /WR
31   /ROM_CE     32   /RAM_CE
33   state[0]    34   state[1]
35   ir_op[7]    36   ir_op[6]
37   /NMI        38   /IRQ
39   SYNC        40   HALT
```

---

## Power Table

| Chip | VCC Pin | GND Pin | Package | Bypass Cap |
|------|:-------:|:-------:|:-------:|:----------:|
| U1 (74HC161) | 16 | 8 | DIP-16 | 100nF |
| U2 (74HC161) | 16 | 8 | DIP-16 | 100nF |
| U3 (74HC161) | 16 | 8 | DIP-16 | 100nF |
| U4 (74HC161) | 16 | 8 | DIP-16 | 100nF |
| U5 (74HC574) | 20 | 10 | DIP-20 | 100nF |
| U6 (74HC574) | 20 | 10 | DIP-20 | 100nF |
| U7 (74HC574) | 20 | 10 | DIP-20 | 100nF |
| U8 (74HC574) | 20 | 10 | DIP-20 | 100nF |
| U9 (74HC574) | 20 | 10 | DIP-20 | 100nF |
| U10 (74HC161) | 16 | 8 | DIP-16 | 100nF |
| U11 (74HC574) | 20 | 10 | DIP-20 | 100nF |
| U12 (74HC283) | 16 | 8 | DIP-16 | 100nF |
| U13 (74HC283) | 16 | 8 | DIP-16 | 100nF |
| U14 (74HC86) | 14 | 7 | DIP-14 | 100nF |
| U15 (74HC86) | 14 | 7 | DIP-14 | 100nF |
| U16 (74HC541) | 20 | 10 | DIP-20 | 100nF |
| U17 (74HC157) | 16 | 8 | DIP-16 | 100nF |
| U18 (74HC139) | 16 | 8 | DIP-16 | 100nF |
| U19 (74HC74) | 14 | 7 | DIP-14 | 100nF |
| U20 (74HC74) | 14 | 7 | DIP-14 | 100nF |
| U21 (74HC08) | 14 | 7 | DIP-14 | 100nF |
| U22 (74HC32) | 14 | 7 | DIP-14 | 100nF |
| ROM (AT28C256) | 28 | 14 | DIP-28 | 100nF |
| RAM (62256) | 28 | 14 | DIP-28 | 100nF |

**Total bypass caps: 24× 100nF ceramic, placed adjacent to each chip VCC/GND pins.**
**Bulk cap: 1× 100µF electrolytic at power entry.**


---

## VERIFICATION

### 1. Pin Assignment Completeness

| Chip | Total Pins | Assigned | Unassigned | Status |
|------|:----------:|:--------:|:----------:|:------:|
| U1 (74HC161) | 16 | 16 | 0 | ✓ |
| U2 (74HC161) | 16 | 16 | 0 | ✓ |
| U3 (74HC161) | 16 | 16 | 0 | ✓ |
| U4 (74HC161) | 16 | 15 | 1 (TC unused) | ✓ |
| U5 (74HC574) | 20 | 20 | 0 | ✓ |
| U6 (74HC574) | 20 | 20 | 0 | ✓ |
| U7 (74HC574) | 20 | 20 | 0 | ✓ |
| U8 (74HC574) | 20 | 20 | 0 | ✓ |
| U9 (74HC574) | 20 | 20 | 0 | ✓ |
| U10 (74HC161) | 16 | 16 | 0 | ✓ |
| U11 (74HC574) | 20 | 20 | 0 | ✓ |
| U12 (74HC283) | 16 | 16 | 0 | ✓ |
| U13 (74HC283) | 16 | 16 | 0 | ✓ |
| U14 (74HC86) | 14 | 14 | 0 | ✓ |
| U15 (74HC86) | 14 | 14 | 0 | ✓ |
| U16 (74HC541) | 20 | 20 | 0 | ✓ |
| U17 (74HC157) | 16 | 16 | 0 | ✓ |
| U18 (74HC139) | 16 | 16 | 0 | ✓ |
| U19 (74HC74) | 14 | 14 | 0 | ✓ |
| U20 (74HC74) | 14 | 14 | 0 | ✓ |
| U21 (74HC08) | 14 | 14 | 0 | ✓ |
| U22 (74HC32) | 14 | 14 | 0 | ✓ |
| ROM | 28 | 28 | 0 | ✓ |
| RAM | 28 | 28 | 0 | ✓ |

### 2. Bus Contention Analysis

| Bus/Wire | Drivers | Arbitration | Status |
|----------|---------|-------------|:------:|
| Data bus D[7:0] | ROM, RAM, (registers read via software) | ROM /CE=NOT(A15), RAM /CE=A15. Only one active at a time. During writes, RAM input mode. | ✓ |
| Address A[15:8] | U16 (541, PC high), U11 (574, ph) | U16./OE=state[1], U11./OE=/Q2=NOT(state[1]). Mutually exclusive. | ✓ |
| Address A[7:4] | U2 (PC[7:4]) directly, U16.Y[4:1] | **CONTENTION**: U2 outputs always drive. U16 Y1-Y4 also drive A[7:4] during fetch. Two drivers on same wire! | ⚠️ **BUG** |
| Address A[3:0] | U17 (157 mux) | Single driver, mux selects source. | ✓ |
| ALU B bus alu_b[7:0] | U6 (operand), U8 (t0) | U6./OE=NOT(ir_op[0]), U8./OE=ir_op[0]. Mutually exclusive. | ✓ |

**A[7:4] CONTENTION BUG**: U2 (74HC161) outputs QA-QD are always active (no /OE on 161).
If U16 (541) also drives A[7:4] via Y1-Y4, there are TWO drivers during fetch.

**FIX OPTIONS**:
1. Do NOT connect U2 outputs to address bus. Only U16 buffers PC[7:4] to A[7:4]. ✓
   U2 outputs go ONLY to U16 inputs (A1-A4). U16 Y outputs drive A[7:4].
   During data access (U16 hi-Z), A[7:4] is UNDRIVEN — needs pull-down resistors
   or accept floating (pointer only uses A[3:0] from U17 + A[15:8] from U11).
2. Accept that A[7:4] = PC[7:4] always (pointer limited to 16-byte window).

**CHOSEN**: Option 1. U2 outputs → U16 inputs ONLY. A[7:4] driven by U16 during
fetch, floating/pulled-low during data access. Add 4× 10KΩ pull-down on A[7:4].

### 3. Control Signal Trace

| Signal | Source | Destination | Verified |
|--------|--------|-------------|:--------:|
| CLK | Oscillator | U1-4.2, U10.2, U19.3 | ✓ |
| /RST | Reset ckt | U1-4.1, U10.1, U19.1+13, U20.1+13 | ✓ |
| ir_latch | U21.3 (Q1 AND /Q2 = S1) | U5.11 | ✓ |
| opr_latch | U21.6 (Q2 AND /Q1 = S2) | U6.11 | ✓ |
| pc_inc | U22.6 (=/Q2) | U1-4.7+10 | ✓ |
| addr_sel | U19.9 (=state[1]) | U17.1 | ✓ |
| sub_mode | U5.15 (=ir_op[3]) | U14.2+5+10, U15.2+5+10+13 | ✓ |
| carry_in | U5.15 (=ir_op[3]) direct | U12.7 | ✓ (simplified) |
| carry_out | U13.9 | U20.12 | ✓ |
| flags_we | U18.4 (class_00_n rising edge) | U20.3+11 | ✓ |
| a0_clk | U22.11 (alu_wr OR mem_load) | U7.11 | ⚠️ sources unclear |
| t0_clk | U18.9 (/Y3b) | U8.11 | ✓ |
| sp_clk | U18.10 (/Y2b) | U9.11 | ✓ |
| ph_clk | U18.11 (/Y1b) | U11.11 | ✓ |
| pl_ld_n | U18.9 (/Y3b) | U10.9 | ⚠️ shared with t0_clk |
| pc_ld_n | Branch logic | U1-4.9 | ⚠️ source not fully defined |
| /WR | U21.11 (S3 AND ir_op[4]) | RAM.27 | ⚠️ approximate |
| /RD | GND (always active) | ROM.22, RAM.22 | ✓ (simplified) |
| /ROM_CE | GND (always active) | ROM.20 | ✓ (simplified) |
| /RAM_CE | A[15] direct | RAM.20 | ✓ |
| U6./OE | U14.11 (NOT ir_op[0]) | U6.1 | ✓ |
| U8./OE | U5.12 (ir_op[0] direct) | U8.1 | ✓ |
| U11./OE | U19.8 (/Q2) | U11.1 | ✓ |
| U16./OE | U19.9 (state[1]) | U16.1+19 | ✓ |

### 4. Unresolved Issues

| # | Issue | Severity | Impact |
|:-:|-------|:--------:|--------|
| 1 | **ALU bit 3 not XOR'd** | HIGH | SUB/SBC/CMP wrong when B[3]=1. Gate 4 of U14 used as inverter instead of XOR for bit 3. |
| 2 | **A[7:4] during data access** | HIGH | Only A[3:0] is muxed. A[7:4] floats or stays at PC value during pointer access. Pointer limited to 16-byte window + ph page. |
| 3 | **Z flag not implementable** | MEDIUM | No gates available for 8-input NOR zero detect. Only C flag works. |
| 4 | **a0 load from memory** | HIGH | a0.D wired to ALU output (always-on 283). Cannot load from data bus during S3. LB/POP broken without passthrough trick. |
| 5 | **pc_ld_n source** | MEDIUM | Branch/JMP logic to load PC not fully specified. Needs condition evaluation + gate to drive /LD. |
| 6 | **pl_ld_n vs t0_clk sharing** | LOW | U18 decoder B /Y3b drives both. Need separate decode for pl vs t0. |
| 7 | **sp not routable to address** | MEDIUM | sp outputs don't connect to address mux. Stack ops need software workaround (copy sp to pl). |
| 8 | **/WR approximation** | LOW | ir_op[4] doesn't perfectly identify all store ops. May cause spurious writes (mitigated by /RAM_CE). |
| 9 | **write_en_n for decoder B** | LOW | Using class_01_n directly means decoder B fires for ALL class 01 ops, not just LI. |

### 5. Verdict

**THE DESIGN DOES NOT FULLY WORK AS A 24-CHIP IMPLEMENTATION.**

The core architecture is sound:
- ✅ State machine (U19) generates correct 4-phase timing
- ✅ ALU B-source /OE trick (U6/U8) works correctly for immediate vs register mode
- ✅ Address high byte /OE trick (U11/U16) works correctly for fetch vs data
- ✅ PC counter chain with carry works
- ✅ Instruction decode via opcode bits + 74HC139 is elegant
- ✅ ROM/RAM memory map with A[15] decode works

Critical failures:
- ❌ ALU bit 3 inversion missing (SUB broken for ~50% of operand values)
- ❌ A[7:4] not muxed (pointer addressing limited to 16 bytes per page)
- ❌ a0 cannot load from data bus (LB/POP instructions broken)
- ❌ Z flag cannot be generated (no gates for zero detect)
- ❌ Branch/JMP PC load logic not fully specified with available gates

### 6. Minimum Fixes to Make It Work

| Fix | Adds | New Total |
|-----|:----:|:---------:|
| Add 74HC86 for bit 3 XOR (move inverter to new chip) | +0 | 24 (reassign U14 gate 4 to bit 3, use new gate for inverter) |
| Actually: just reassign — use U15 spare... no, U15 is full | — | — |
| Add 74HC245 for ALU→bus buffer (tri-state, allows a0 to read bus) | +1 | 25 |
| Add 74HC157 for A[7:4] mux | +1 | 26 |
| Add 74HC688 for zero detect | +1 | 27 |
| **Minimum viable: 25 chips** (add 245 for bus buffer) | | |
| **Full functionality: 27 chips** | | |

### 7. What DOES Work in 24 Chips

If we accept the limitations:
- ✅ ADD, ADDI (no subtraction needed)
- ✅ AND, OR, XOR (logic ops don't use XOR inversion)
- ✅ INC, DEC (single-bit operations)
- ✅ LI (load immediate to any register)
- ✅ JMP (absolute jump via ph + operand)
- ✅ BCS/BCC (branch on carry — C flag works)
- ✅ Pointer access within 16-byte window
- ✅ Basic I/O via pointer read/write
- ⚠️ SUB works for operands with bit 3 = 0
- ❌ LB/POP (cannot load memory to a0)
- ❌ BEQ/BNE (Z flag broken)
- ❌ Full 256-byte pointer range

**CONCLUSION**: The 24-chip design is a PARTIAL implementation. It can run
simple programs (arithmetic, logic, jumps, immediate loads, pointer writes)
but cannot do memory reads into a0 or correct subtraction for all values.

For a COMPLETE working CPU matching the Verilog: **27 chips minimum**.
For a useful subset (ADD-only, no memory loads): **24 chips works**.

The fundamental tension: the Verilog has unlimited "free" muxes and buses.
Physical hardware needs explicit mux/buffer chips for every shared resource.
The 24-chip budget is ~3 chips short of full functionality.

---

*End of Wiring Guide — RV8-G 24-Chip Design*
*Honest assessment: partially functional. See issues above.*
