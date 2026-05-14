# RV8-G Wiring Guide

## CRITICAL NOTE: 23-Chip Budget Analysis

**The design CANNOT fully fit in 23 chips as specified.** Here's why:

The address mux needs to route A[15:0] between:
- PC (16-bit) during fetch (S0/S1)
- {ph, pl} during pointer access
- {$00, operand} during zero-page access
- {$30, sp} during stack access

U15-U16 (2× 74HC157) provide only 8 mux bits total (4 channels × 2 chips = 8 outputs).
To mux the full 16-bit address requires 4× 74HC157 (2 for low byte, 2 for high byte).

**Workaround used here**: U15-U16 mux the LOW byte only (A[7:0]). For the HIGH byte (A[15:8]):
- During fetch: PC high (U3-U4) drives A[15:8] directly via bus contention avoidance
- During data access: pointer high (U11), $00, or $30 must be selected

**Options to resolve (pick one):**
1. Add 2× 74HC157 for high byte mux → 25 chips total
2. Use active-low /OE on 74HC574 registers to tri-state multiplex (U11 has /OE) → works for pointer, but $00 and $30 need pull-down/pull-up tricks
3. Hardwire: stack always at page $00 (not $30), zero-page also $00 → then high byte is just "PC high when fetch, $00 otherwise" = 1 signal controls 8 pull-downs

**This guide uses Option 3** (simplest, fits 23 chips): Stack lives at $00xx alongside zero-page. The sp register provides isolation (sp starts at $FF, counts down; zero-page vars use low addresses). High byte during data access = $00 (active pull-down via resistor network or just tie U15-U16 B-high inputs to GND).

Actually, re-examining: we use U15-U16 as 2× 74HC157 = 8 mux outputs. We assign:
- U15: muxes A[3:0] (4 bits: S=addr_sel, A=PC_lo[3:0], B=data_addr[3:0])
- U16: muxes A[7:4] (4 bits: S=addr_sel, A=PC_lo[7:4], B=data_addr[7:4])
- A[15:8]: directly from PC high (U3-U4) when addr_sel=0, or from U11(ph)/GND when addr_sel=1

For A[15:8] high byte routing without extra mux: U3-U4 outputs have active drive. U11 (ph as 74HC161) also has active outputs. We use addr_sel to control /OE or ENP on the counters — but 74HC161 has no /OE pin!

**Final honest answer: Need 2 more 74HC157 chips (U22-U23 renumbered) = 25 chips, OR accept the $00-page-only workaround for 23 chips.**

This guide documents the **23-chip version with the $00-page workaround** (stack at $00xx, zero-page at $00xx, pointer uses {ph,pl} full 16-bit via the 2 extra high-byte lines directly from U11 accent accent — see notes per chip).

---

```
{
Project: RV8-G (Gates-Only 8-bit CPU),
Target: 23 chips (21 logic + ROM + RAM),
Clock: 3.5 MHz,
Note: "High byte mux limited - see analysis above"
}
```

---

## Bus Signal Definitions

| Signal | Dir | Source → Consumer | Description |
|--------|:---:|-------------------|-------------|
| VCC | PWR | PSU → all chips pin VCC | +5V supply |
| GND | PWR | PSU → all chips pin GND | Ground |
| CLK | → | Oscillator → U18.3(FF1 CLK) | 3.5 MHz master clock |
| /RST | → | Reset ckt → U1-U4.1, U10-U11.1, U18.1+13 | Active-low master reset |
| A[0] | ← | U15.4 → ROM.10, RAM.10 | Address bus bit 0 |
| A[1] | ← | U15.7 → ROM.9, RAM.9 | Address bus bit 1 |
| A[2] | ← | U15.9 → ROM.8, RAM.8 | Address bus bit 2 |
| A[3] | ← | U15.12 → ROM.7, RAM.7 | Address bus bit 3 |
| A[4] | ← | U16.4 → ROM.6, RAM.6 | Address bus bit 4 |
| A[5] | ← | U16.7 → ROM.5, RAM.5 | Address bus bit 5 |
| A[6] | ← | U16.9 → ROM.4, RAM.4 | Address bus bit 6 |
| A[7] | ← | U16.12 → ROM.3, RAM.3 | Address bus bit 7 |
| A[8] | ← | U3.14 / U11.14 (see notes) → ROM.25, RAM.25 | Address bus bit 8 |
| A[9] | ← | U3.13 / U11.13 → ROM.24, RAM.24 | Address bus bit 9 |
| A[10] | ← | U3.12 → ROM.21, RAM.21 | Address bus bit 10 |
| A[11] | ← | U3.11 → ROM.23, RAM.23 | Address bus bit 11 |
| A[12] | ← | U4.14 → ROM.2, RAM.2 | Address bus bit 12 |
| A[13] | ← | U4.13 → ROM.26, RAM.26 | Address bus bit 13 |
| A[14] | ← | U4.12 → ROM.1, RAM.1 | Address bus bit 14 |
| A[15] | ← | U4.11 → decode logic | Address bus bit 15 (directly from PC, directly from PC, directly from PC, used for ROM/RAM select) |
| D[0] | ↔ | ROM.11, RAM.11 ↔ U5.2, U6.2, U7.2, U8.2, U9.2 | Data bus bit 0 |
| D[1] | ↔ | ROM.12, RAM.12 ↔ U5.3, U6.3, U7.3, U8.3, U9.3 | Data bus bit 1 |
| D[2] | ↔ | ROM.13, RAM.13 ↔ U5.4, U6.4, U7.4, U8.4, U9.4 | Data bus bit 2 |
| D[3] | ↔ | ROM.15, RAM.15 ↔ U5.5, U6.5, U7.5, U8.5, U9.5 | Data bus bit 3 |
| D[4] | ↔ | ROM.16, RAM.16 ↔ U5.6, U6.6, U7.6, U8.6, U9.6 | Data bus bit 4 |
| D[5] | ↔ | ROM.17, RAM.17 ↔ U5.7, U6.7, U7.7, U8.7, U9.7 | Data bus bit 5 |
| D[6] | ↔ | ROM.18, RAM.18 ↔ U5.8, U6.8, U7.8, U8.8, U9.8 | Data bus bit 6 |
| D[7] | ↔ | ROM.19, RAM.19 ↔ U5.9, U6.9, U7.9, U8.9, U9.9 | Data bus bit 7 |
| /RD | → | U18./Q2 (pin 8) → ROM.22, RAM.22 | Read strobe (active during S0,S1 fetch) |
| /WR | → | U20.6 → RAM.27 | Write strobe |
| addr_sel | → | U20.3 (=S2 signal) → U15.1, U16.1 | Address mux select: 0=PC, 1=data addr |
| ir_latch | → | U20.6 or derived → U5.11 | IR opcode latch clock (rising edge at S1) |
| opr_latch | → | derived → U6.11 | IR operand latch clock (rising edge at S2) |
| a0_clk | → | U21.3 → U7.11 | Accumulator write clock |
| t0_clk | → | derived → U8.11 | Temp register write clock |
| sp_clk | → | derived → U9.11 | Stack pointer write clock |
| pl_ld | → | derived → U10.9 | Pointer low load |
| ph_ld | → | derived → U11.9 | Pointer high load |
| ptr_inc | → | derived → U10.7+10 | Pointer increment enable |
| pc_inc | → | /Q2 (U18.8) → U1.7+10, U2.7+10, U3.7+10, U4.7+10 | PC increment (active S0,S1) |
| pc_ld | → | branch logic → U1.9, U2.9, U3.9, U4.9 | PC parallel load |
| flags_we | → | U20.8 → U19.3, U19.11 | Flags write enable |
| write_en | → | U17 decoder B enable | Register write enable |
| S2 | → | U20.3 (Q2 AND /Q1) → U17.6(G1) | State 2 active |
| S3 | → | U20.6 (Q2 AND Q1) | State 3 active |
| class_00 | → | U17.15 (/Y0, active low) | ALU class active |
| class_01 | → | U17.14 (/Y1, active low) | Load/Store class active |
| class_10 | → | U17.13 (/Y2, active low) | Branch class active |
| class_11 | → | U17.12 (/Y3, active low) | System class active |
| sub_mode | → | ir_op[3] (U5.16) direct wire → U14 XOR B inputs | SUB/CMP invert control |
| carry_in | → | derived from ir_op[3]+ir_op[1]+flag_c → U12.7 | ALU carry input |
| branch_taken | → | U14.11 (XOR gate 4) → pc_ld logic | Branch condition met |
| /ROM_CE | → | A[15] inverted → ROM.20 | ROM chip enable (A[15]=1 → ROM) |
| /RAM_CE | → | A[15] → RAM.20 | RAM chip enable (A[15]=0 → RAM) |
| /IO_CE | → | (optional, directly from decode) | I/O chip enable |
| SYNC | → | U18.Q1 (state[0]) → bus connector | State sync output |
| HALT | → | (directly from opcode detect) → bus connector | Halt indicator |
| /NMI | ← | bus connector → interrupt logic | Non-maskable interrupt |
| /IRQ | ← | bus connector → interrupt logic | Maskable interrupt |


---

## Part List — Pin-by-Pin Wiring

### U1: 74HC161 — PC bit [3:0] (Program Counter, lowest nibble)

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR    /RST            Reset circuit (active low)
2    CLK     CLK             Master clock (3.5 MHz oscillator)
3    D0      D[0]            Data bus bit 0 (for PC load on branch)
4    D1      D[1]            Data bus bit 1
5    D2      D[2]            Data bus bit 2
6    D3      D[3]            Data bus bit 3
7    ENP     pc_inc          U21.3 (OR gate: fetch phase enable)
8    GND     GND             Ground
9    /LD     pc_ld           Branch logic (active low to load)
10   ENT     pc_inc          Same as pin 7
11   QD      PC[3]           → U15.14 (mux A3 input)
12   QC      PC[2]           → U15.11 (mux A2 input)
13   QB      PC[1]           → U15.5 (mux A1 input)
14   QA      PC[0]           → U15.2 (mux A0 input)
15   TC      carry_0_1       → U2.10 (ENT of next counter)
16   VCC     VCC             +5V
```

### U2: 74HC161 — PC bit [7:4]

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR    /RST            Reset circuit
2    CLK     CLK             Master clock
3    D0      D[4]            Data bus bit 4 (for PC load)
4    D1      D[5]            Data bus bit 5
5    D2      D[6]            Data bus bit 6
6    D3      D[7]            Data bus bit 7
7    ENP     pc_inc          U21.3
8    GND     GND             Ground
9    /LD     pc_ld           Branch logic
10   ENT     carry_0_1       ← U1.15 (TC from U1)
11   QD      PC[7]           → U16.14 (mux A3 input)
12   QC      PC[6]           → U16.11 (mux A2 input)
13   QB      PC[5]           → U16.5 (mux A1 input)
14   QA      PC[4]           → U16.2 (mux A0 input)
15   TC      carry_1_2       → U3.10 (ENT of next counter)
16   VCC     VCC             +5V
```

### U3: 74HC161 — PC bit [11:8]

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR    /RST            Reset circuit
2    CLK     CLK             Master clock
3    D0      (note 1)        For branch: operand sign-extend or ph
4    D1      (note 1)        (see branch logic notes below)
5    D2      (note 1)        
6    D3      (note 1)        
7    ENP     pc_inc          U21.3
8    GND     GND             Ground
9    /LD     pc_ld           Branch logic
10   ENT     carry_1_2       ← U2.15 (TC from U2)
11   QD      A[11]           → ROM.23, RAM.23
12   QC      A[10]           → ROM.21, RAM.21
13   QB      A[9]            → ROM.24, RAM.24
14   QA      A[8]            → ROM.25, RAM.25
15   TC      carry_2_3       → U4.10 (ENT of next counter)
16   VCC     VCC             +5V
```
Note 1: For JMP instruction, D[3:0] loaded from ph register (U11 outputs).
For relative branch, these bits get sign-extension of operand[7].

### U4: 74HC161 — PC bit [15:12]

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR    /RST            Reset circuit
2    CLK     CLK             Master clock
3    D0      (note 2)        For JMP: from ph[4] or sign-extend
4    D1      (note 2)        
5    D2      (note 2)        
6    D3      (note 2)        
7    ENP     pc_inc          U21.3
8    GND     GND             Ground
9    /LD     pc_ld           Branch logic
10   ENT     carry_2_3       ← U3.15 (TC from U3)
11   QD      A[15]           → /ROM_CE logic, /RAM_CE logic
12   QC      A[14]           → ROM.1, RAM.1
13   QB      A[13]           → ROM.26, RAM.26
14   QA      A[12]           → ROM.2, RAM.2
15   TC      (unused)        NC (no further carry needed)
16   VCC     VCC             +5V
```
Note 2: For JMP, D[3:0] from ph[7:4]. Reset loads $C (=0xC000 start).
On /CLR, 74HC161 resets to 0000. To start at $C000, tie D=$C and assert /LD at reset release, OR use external pull-up on D2+D3 with a reset-load pulse.

**Reset vector trick**: After /RST releases, first instruction fetches from $0000. Place a JMP $C000 at address $0000 in ROM, OR map ROM to both $0000 and $C000 by ignoring A[15] in ROM /CE decode.


---

### U5: 74HC574 — IR Opcode Register

Latches opcode byte at end of S0 (rising edge of ir_latch).
Outputs drive decode logic (U17) and ALU control.

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /OE     GND             Always enabled (active low)
2    D0      D[0]            Data bus bit 0
3    D1      D[1]            Data bus bit 1
4    D2      D[2]            Data bus bit 2
5    D3      D[3]            Data bus bit 3
6    D4      D[4]            Data bus bit 4
7    D5      D[5]            Data bus bit 5
8    D6      D[6]            Data bus bit 6
9    D7      D[7]            Data bus bit 7
10   GND     GND             Ground
11   CLK     ir_latch        U20.3 (AND: CLK AND S0→S1 transition)
12   Q0      ir_op[0]        → modf[0]: register select, imm mode
13   Q1      ir_op[1]        → modf[1]: carry/shift mode select
14   Q2      ir_op[2]        → modf[2]: register select
15   Q3      ir_op[3]        → op[0]: ALU op bit 0, sub_mode → U14 XOR
16   Q4      ir_op[4]        → op[1]: ALU op bit 1
17   Q5      ir_op[5]        → op[2]: ALU op bit 2
18   Q6      ir_op[6]        → class[0] → U17.1 (decoder A input)
19   Q7      ir_op[7]        → class[1] → U17.2 (decoder B input)
20   VCC     VCC             +5V
```

### U6: 74HC574 — IR Operand Register

Latches operand byte at end of S1 (rising edge of opr_latch).
Outputs go to ALU B input (immediate mode), address mux B, branch offset.

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /OE     GND             Always enabled
2    D0      D[0]            Data bus bit 0
3    D1      D[1]            Data bus bit 1
4    D2      D[2]            Data bus bit 2
5    D3      D[3]            Data bus bit 3
6    D4      D[4]            Data bus bit 4
7    D5      D[5]            Data bus bit 5
8    D6      D[6]            Data bus bit 6
9    D7      D[7]            Data bus bit 7
10   GND     GND             Ground
11   CLK     opr_latch       U20.8 (AND: CLK AND S1→S2 transition)
12   Q0      opr[0]          → U14.1(XOR A0), U15.3(mux B0), U10.3(ptr D0)
13   Q1      opr[1]          → U14.4(XOR A1), U15.6(mux B1), U10.4(ptr D1)
14   Q2      opr[2]          → U14.9(XOR A2), U15.10(mux B2), U10.5(ptr D2)
15   Q3      opr[3]          → U14.12(XOR A3), U15.13(mux B3), U10.6(ptr D3)
16   Q4      opr[4]          → U12.5(adder A1 hi), U16.3(mux B0 hi)
17   Q5      opr[5]          → U12.3(adder A2 hi), U16.6(mux B1 hi)
18   Q6      opr[6]          → U12.14(adder A3 hi), U16.10(mux B2 hi)
19   Q7      opr[7]          → U12.12(adder A4 hi), U16.13(mux B3 hi), sign-ext
20   VCC     VCC             +5V
```

### U7: 74HC574 — a0 Accumulator

Latches ALU result. Outputs feed back to ALU A input.

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /OE     GND             Always enabled
2    D0      alu_out[0]      U13.4 (adder S1 low) — ALU result bit 0
3    D1      alu_out[1]      U13.1 (adder S2 low) — ALU result bit 1
4    D2      alu_out[2]      U13.13 (adder S3 low) — ALU result bit 2
5    D3      alu_out[3]      U13.10 (adder S4 low) — ALU result bit 3
6    D4      alu_out[4]      U12.4 (adder S1 high) — ALU result bit 4
7    D5      alu_out[5]      U12.1 (adder S2 high) — ALU result bit 5
8    D6      alu_out[6]      U12.13 (adder S3 high) — ALU result bit 6
9    D7      alu_out[7]      U12.10 (adder S4 high) — ALU result bit 7
10   GND     GND             Ground
11   CLK     a0_clk          U21.3 (OR: alu_write OR mem_load)
12   Q0      a0[0]           → U13.6 (adder B1 low — A input of ALU)
13   Q1      a0[1]           → U13.2 (adder B2 low... 
```

**CORRECTION** — 74HC283 pinout: A inputs are the "A" operand, B inputs are "B" operand. Let me use correct 283 pins:

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /OE     GND             Always enabled
2    D0      alu_out[0]      ← U13.4 (Sum1) or D[0] via mux/gate
3    D1      alu_out[1]      ← U13.1 (Sum2) or D[1]
4    D2      alu_out[2]      ← U13.13 (Sum3) or D[2]
5    D3      alu_out[3]      ← U13.10 (Sum4) or D[3]
6    D4      alu_out[4]      ← U12.4 (Sum1) or D[4]
7    D5      alu_out[5]      ← U12.1 (Sum2) or D[5]
8    D6      alu_out[6]      ← U12.13 (Sum3) or D[6]
9    D7      alu_out[7]      ← U12.10 (Sum4) or D[7]
10   GND     GND             Ground
11   CLK     a0_clk          U21.3 (OR gate output)
12   Q0      a0[0]           → U13.5 (A1 of low adder)
13   Q1      a0[1]           → U13.3 (A2 of low adder)
14   Q2      a0[2]           → U13.14 (A3 of low adder)
15   Q3      a0[3]           → U13.12 (A4 of low adder)
16   Q4      a0[4]           → U12.5 (A1 of high adder)
17   Q5      a0[5]           → U12.3 (A2 of high adder)
18   Q6      a0[6]           → U12.14 (A3 of high adder)
19   Q7      a0[7]           → U12.12 (A4 of high adder)
20   VCC     VCC             +5V
```

Note: a0 D inputs come from ALU result during ALU ops, or from data bus during LB/POP.
This requires a mux or tri-state selection. In the 23-chip design, the adder always computes
a0+B; for loads, B=0 and carry_in=0 so result = a0+0 = a0 (passthrough). The data bus
value is loaded by clocking a0 while data_in is on the bus — meaning a0.D connects
DIRECTLY to the data bus D[7:0], and ALU result also drives D[7:0] during execute.
**Simplification**: a0.D[7:0] = D[7:0] (data bus). ALU result is written to data bus
during S2 (ALU drives bus), memory data appears on bus during S3 (RAM/ROM drives bus).

**Revised U7 wiring:**
```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /OE     GND             Always enabled
2    D0      D[0]            Data bus bit 0
3    D1      D[1]            Data bus bit 1
4    D2      D[2]            Data bus bit 2
5    D3      D[3]            Data bus bit 3
6    D4      D[4]            Data bus bit 4
7    D5      D[5]            Data bus bit 5
8    D6      D[6]            Data bus bit 6
9    D7      D[7]            Data bus bit 7
10   GND     GND             Ground
11   CLK     a0_clk          U21.3 (OR: S2&class_00 | S3&is_load)
12   Q0      a0[0]           → U13.5 (A1 of low adder)
13   Q1      a0[1]           → U13.3 (A2 of low adder)
14   Q2      a0[2]           → U13.14 (A3 of low adder)
15   Q3      a0[3]           → U13.12 (A4 of low adder)
16   Q4      a0[4]           → U12.5 (A1 of high adder)
17   Q5      a0[5]           → U12.3 (A2 of high adder)
18   Q6      a0[6]           → U12.14 (A3 of high adder)
19   Q7      a0[7]           → U12.12 (A4 of high adder)
20   VCC     VCC             +5V
```

### U8: 74HC574 — t0 Temp Register

Latches data bus value. Output goes to ALU B input (register mode).

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /OE     GND             Always enabled
2    D0      D[0]            Data bus bit 0
3    D1      D[1]            Data bus bit 1
4    D2      D[2]            Data bus bit 2
5    D3      D[3]            Data bus bit 3
6    D4      D[4]            Data bus bit 4
7    D5      D[5]            Data bus bit 5
8    D6      D[6]            Data bus bit 6
9    D7      D[7]            Data bus bit 7
10   GND     GND             Ground
11   CLK     t0_clk          From register write decode (U17b or gate)
12   Q0      t0[0]           → U14.2 (XOR 1B) when reg mode (ir_op[0]=0)
13   Q1      t0[1]           → U14.5 (XOR 2B) when reg mode
14   Q2      t0[2]           → U14.9 (XOR 3A) when reg mode
15   Q3      t0[3]           → U14.12 (XOR 4A) when reg mode
16   Q4      t0[4]           → U12.6 (B1 high adder) when reg mode
17   Q5      t0[5]           → U12.2 (B2 high adder) when reg mode
18   Q6      t0[6]           → U12.15 (B3 high adder) when reg mode
19   Q7      t0[7]           → U12.11 (B4 high adder) when reg mode
20   VCC     VCC             +5V
```

Note: ALU B source selection (t0 vs operand) is controlled by ir_op[0].
When ir_op[0]=1 (immediate), operand register U6 outputs feed ALU B.
When ir_op[0]=0 (register), t0 register U8 outputs feed ALU B.
This requires a mux — in the minimal design, use the XOR gates (U14) for low nibble
and direct wiring for high nibble with ir_op[0] selecting via additional logic.
**Problem**: This needs another mux chip. See "Fit Analysis" at end.

### U9: 74HC574 — sp Stack Pointer

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /OE     GND             Always enabled
2    D0      D[0]            Data bus bit 0
3    D1      D[1]            Data bus bit 1
4    D2      D[2]            Data bus bit 2
5    D3      D[3]            Data bus bit 3
6    D4      D[4]            Data bus bit 4
7    D5      D[5]            Data bus bit 5
8    D6      D[6]            Data bus bit 6
9    D7      D[7]            Data bus bit 7
10   GND     GND             Ground
11   CLK     sp_clk          From register write decode
12   Q0      sp[0]           → U15.3 (mux B0) during stack access
13   Q1      sp[1]           → U15.6 (mux B1) during stack access
14   Q2      sp[2]           → U15.10 (mux B2) during stack access
15   Q3      sp[3]           → U15.13 (mux B3) during stack access
16   Q4      sp[4]           → U16.3 (mux B0 hi) during stack access
17   Q5      sp[5]           → U16.6 (mux B1 hi) during stack access
18   Q6      sp[6]           → U16.10 (mux B2 hi) during stack access
19   Q7      sp[7]           → U16.13 (mux B3 hi) during stack access
20   VCC     VCC             +5V
```

Note: sp outputs share the mux B inputs with operand (U6) and pointer low (U10).
The address mux B input source depends on the instruction type:
- Zero-page: B = operand (U6 Q[7:0])
- Stack: B = sp (U9 Q[7:0])
- Pointer: B = pl (U10 Q[3:0]) + ph (U11 Q[3:0])
This is ANOTHER mux conflict. In the 23-chip design, we resolve by:
- Using sp as a 74HC161 counter (increment/decrement) and routing its output
  to the address mux B input ONLY during stack operations
- **Honest assessment**: needs tri-state or additional mux. See final notes.


---

### U10: 74HC161 — Pointer Low (pl)

Loadable counter for pointer low byte. Auto-increments for LB(ptr+).

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR    /RST            Reset circuit
2    CLK     CLK             Master clock
3    D0      D[0]            Data bus (for LI pl,imm)
4    D1      D[1]            Data bus
5    D2      D[2]            Data bus
6    D3      D[3]            Data bus
7    ENP     ptr_inc         Pointer increment enable (LB ptr+ mode)
8    GND     GND             Ground
9    /LD     pl_ld           Load enable (active low, from LI pl decode)
10   ENT     ptr_inc         Same as ENP (both must be high to count)
11   QD      pl[3]           → U15.13 (mux B3) for pointer address low
12   QC      pl[2]           → U15.10 (mux B2)
13   QB      pl[1]           → U15.5 (mux B1) — NOTE: shared with other B sources
14   QA      pl[0]           → U15.3 (mux B0) — NOTE: shared
15   TC      pl_carry        → U11.10 (ENT, carry to pointer high)
16   VCC     VCC             +5V
```

### U11: 74HC161 — Pointer High (ph)

Loadable counter for pointer high byte. Carries from pl for 16-bit increment.

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR    /RST            Reset circuit
2    CLK     CLK             Master clock
3    D0      D[0]            Data bus (for LI ph,imm)
4    D1      D[1]            Data bus
5    D2      D[2]            Data bus
6    D3      D[3]            Data bus
7    ENP     ptr_inc         Pointer increment enable
8    GND     GND             Ground
9    /LD     ph_ld           Load enable (active low, from LI ph decode)
10   ENT     pl_carry        ← U10.15 (carry from pointer low)
11   QD      ph[3]           → U16.13 (mux B3 hi) / A[11] during ptr access
12   QC      ph[2]           → U16.10 (mux B2 hi) / A[10]
13   QB      ph[1]           → U16.5 (mux B1 hi) / A[9]
14   QA      ph[0]           → U16.2 (mux B0 hi) / A[8]
15   TC      (unused)        NC
16   VCC     VCC             +5V
```

Note: U10-U11 only provide 8 bits (4+4) for the pointer. The full 16-bit pointer
{ph[3:0], pl[3:0]} only gives 8 bits. For a full 16-bit pointer we need the 574
approach from the Verilog (8-bit pl + 8-bit ph). Using 74HC161 ×2 gives only
4+4=8 address bits for the pointer — this is a DESIGN LIMITATION.

**Resolution**: Use 74HC161 as 4-bit counters with carry chain. For 8-bit pl:
need 2× 74HC161 (U10a for pl[3:0], U10b for pl[7:4]). But we only have 2 chips
allocated (U10-U11). So pointer is limited to {ph[3:0], pl[7:0]} = 12-bit = 4KB
pages. The Verilog uses full 8+8=16 bit pointer.

**Practical fix**: U10 = pl[7:4,3:0] needs to be a 74HC574 (8-bit latch) not 161.
But then we lose auto-increment. The design doc says "74HC161 ×2 with carry chain
and auto-increment" — this only works for 8 total bits. Accept 8-bit pointer
(256-byte window) with 4-bit page select, OR change U10-U11 to 74HC574 and
lose auto-increment, OR add more chips.

**This guide follows the task spec**: U10-U11 as 74HC161 ×2, giving {U11[3:0], U10[3:0]}
= 8-bit pointer with auto-increment. For full 16-bit access, use LI ph + LI pl
to set page, then LB(ptr+) walks within the 256-byte page.

---

### U12: 74HC283 — ALU Adder High Nibble (bits [7:4])

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    S2      alu_out[5]      → U7.7 (a0 D5 via bus), sum bit 5
2    B2      alu_b[5]        ← XOR output or direct (see note)
3    A2      a0[5]           ← U7.17 (a0 Q5)
4    S1      alu_out[4]      → U7.6 (a0 D4 via bus), sum bit 4
5    A1      a0[4]           ← U7.16 (a0 Q4)
6    B1      alu_b[4]        ← operand[4]/t0[4] (see B-source note)
7    C0      carry_lo_hi     ← U13.9 (C4 carry out from low adder)
8    GND     GND             Ground
9    C4      carry_out       → U19.12 (D2, C flag input)
10   S4      alu_out[7]      → U7.9 (a0 D7 via bus), sum bit 7
11   B4      alu_b[7]        ← operand[7]/t0[7]
12   A4      a0[7]           ← U7.19 (a0 Q7)
13   S3      alu_out[6]      → U7.8 (a0 D6 via bus), sum bit 6
14   A3      a0[6]           ← U7.18 (a0 Q6)
15   B3      alu_b[6]        ← operand[6]/t0[6]
16   VCC     VCC             +5V
```

Note on B inputs: High nibble B[7:4] comes directly from operand (U6 Q[4:7])
or t0 (U8 Q[4:7]) without XOR inversion. For SUB, only the low nibble is
XOR-inverted (with carry_in=1 for two's complement). The high nibble gets
the carry propagation from the low nibble which handles the inversion.

**CORRECTION**: For proper 8-bit subtraction, ALL 8 B-input bits must be XOR'd
with sub_mode. We only have 4 XOR gates (U14). This means:
- U14 handles B[3:0] XOR sub_mode (4 gates used)
- B[7:4] needs 4 more XOR gates = need another 74HC86!

**This is another chip-count problem.** Workaround: use the adder's carry
propagation — if low nibble is inverted with C0=1, the carry chain handles
the rest IF we also invert the high nibble. With only 4 XOR gates, we CANNOT
do full 8-bit subtraction properly.

**Honest answer**: Need U14a (second 74HC86) for high nibble inversion = 24 chips.
OR: accept that SUB only works on low nibble (4-bit subtract) — unacceptable.
OR: use a different trick — see final analysis.

**Trick that works**: Feed B[7:4] through the SAME XOR pattern by time-multiplexing
— not possible in combinational logic.

**Real solution used in many minimal CPUs**: The 74HC283 subtraction trick:
- For SUB: invert ALL B bits and set C0=1 (two's complement)
- Use 2× 74HC86 (8 XOR gates) for full inversion
- OR: use 1× 74HC86 (4 gates) for low nibble + wire high nibble B inputs
  through the UNUSED gates... but there are no unused gates.

**This guide acknowledges: need 2× 74HC86 for proper 8-bit SUB = 24 chips minimum.**
For the 23-chip version, we document the 4-gate XOR with the understanding that
a second XOR chip is needed for production. See final chip count analysis.

### U13: 74HC283 — ALU Adder Low Nibble (bits [3:0])

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    S2      alu_out[1]      → data bus D[1] (during ALU write)
2    B2      alu_b_xor[1]    ← U14.6 (XOR gate 2 output)
3    A2      a0[1]           ← U7.13 (a0 Q1)
4    S1      alu_out[0]      → data bus D[0]
5    A1      a0[0]           ← U7.12 (a0 Q0)
6    B1      alu_b_xor[0]    ← U14.3 (XOR gate 1 output)
7    C0      carry_in        ← carry logic (0 for ADD, 1 for SUB, flag_c for ADC)
8    GND     GND             Ground
9    C4      carry_lo_hi     → U12.7 (C0 of high adder, carry chain)
10   S4      alu_out[3]      → data bus D[3]
11   B4      alu_b_xor[3]    ← U14.11 (XOR gate 4 output)
12   A4      a0[3]           ← U7.15 (a0 Q3)
13   S3      alu_out[2]      → data bus D[2]
14   A3      a0[2]           ← U7.14 (a0 Q2)
15   B3      alu_b_xor[2]    ← U14.8 (XOR gate 3 output)
16   VCC     VCC             +5V
```

### U14: 74HC86 — XOR Gates (SUB invert + branch condition)

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    1A      alu_b_raw[0]    ← operand[0] (U6.12) or t0[0] (U8.12)
2    1B      sub_mode        ← ir_op[3] (U5.15) — invert for SUB/SBC/CMP
3    1Y      alu_b_xor[0]   → U13.6 (B1 of low adder)
4    2A      alu_b_raw[1]    ← operand[1] (U6.13) or t0[1] (U8.13)
5    2B      sub_mode        ← ir_op[3] (U5.15)
6    2Y      alu_b_xor[1]   → U13.2 (B2 of low adder)
7    GND     GND             Ground
8    3Y      alu_b_xor[2]   → U13.15 (B3 of low adder)
9    3A      alu_b_raw[2]    ← operand[2] (U6.14) or t0[2] (U8.14)
10   3B      sub_mode        ← ir_op[3] (U5.15)
11   4Y      branch_cond_inv → branch_taken logic (flag XOR invert bit)
12   4A      flag_selected   ← flag mux output (Z or C based on ir_op[3])
13   4B      ir_op[5]        ← U5.17 (invert bit for branch condition)
14   VCC     VCC             +5V
```

Note: Gate 4 is used for branch condition inversion (flag XOR opcode[5]).
This means only 3 XOR gates available for SUB inversion (bits 0-2 only).
Bit 3 of the low nibble has NO XOR gate — **critical problem**.

**Revised allocation**: Use all 4 gates for ALU B inversion (bits 0-3).
Move branch condition inversion to a spare gate elsewhere (U20/U21).
Branch inversion can use an AND+OR combination instead of XOR:
`branch_taken = (flag AND NOT(invert)) OR (NOT(flag) AND invert)`
This needs 2 AND + 1 OR — too many gates.

**Final decision**: Use 3 XOR for B[2:0], 1 XOR for branch. B[3] goes un-inverted
to adder — the carry chain from bits 0-2 will propagate correctly for most cases
but gives WRONG results for SUB when bit 3 of B is 1. This is a KNOWN LIMITATION
of the 23-chip design.

**Production fix**: Add second 74HC86 (U14b) = 24 chips.


---

### U15: 74HC157 — Address Mux Low Nibble (A[3:0])

Selects between PC[3:0] (fetch) and data address[3:0] (memory access).

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    S       addr_sel        ← state[1] (U18 Q2): 0=fetch(PC), 1=execute(data)
2    1A      PC[0]           ← U1.14 (QA)
3    1B      data_addr[0]    ← U10.14 (pl QA) / U6.12 (opr[0]) / U9.12 (sp[0])
4    1Y      A[0]            → ROM.10, RAM.10, bus connector
5    2A      PC[1]           ← U1.13 (QB)
6    2B      data_addr[1]    ← U10.13 (pl QB) / U6.13 (opr[1]) / U9.13 (sp[1])
7    2Y      A[1]            → ROM.9, RAM.9, bus connector
8    GND     GND             Ground
9    3Y      A[2]            → ROM.8, RAM.8, bus connector
10   3B      data_addr[2]    ← U10.12 (pl QC) / U6.14 (opr[2]) / U9.14 (sp[2])
11   3A      PC[2]           ← U1.12 (QC)
12   4Y      A[3]            → ROM.7, RAM.7, bus connector
13   4B      data_addr[3]    ← U10.11 (pl QD) / U6.15 (opr[3]) / U9.15 (sp[3])
14   4A      PC[3]           ← U1.11 (QD)
15   /E      GND             Always enabled (active low)
16   VCC     VCC             +5V
```

**B-input conflict**: Three sources (pl, operand, sp) share the B inputs.
In the 23-chip design, only ONE source can be wired to B at a time.
Resolution: Wire pl (U10) to B inputs. For zero-page, pre-load pl with the
operand value. For stack, pre-load pl with sp value. This requires extra
clock cycles but avoids extra mux chips.

**Simpler approach**: Wire operand (U6) directly to B inputs since it's the
most common data address source (zero-page, branch offset). For pointer access,
the operand register is pre-loaded with pl value during S1 — but this conflicts
with the actual operand fetch.

**Honest routing**: In practice, the B inputs need a sub-mux or tri-state.
This guide wires U10 (pl) to B inputs as the primary data address source.

### U16: 74HC157 — Address Mux High Nibble (A[7:4])

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    S       addr_sel        ← state[1] (U18 Q2): same as U15
2    1A      PC[4]           ← U2.14 (QA)
3    1B      data_addr[4]    ← U10 high nibble or U6.16 (opr[4]) or U9.16
4    1Y      A[4]            → ROM.6, RAM.6, bus connector
5    2A      PC[5]           ← U2.13 (QB)
6    2B      data_addr[5]    ← source (see U15 note)
7    2Y      A[5]            → ROM.5, RAM.5, bus connector
8    GND     GND             Ground
9    3Y      A[6]            → ROM.4, RAM.4, bus connector
10   3B      data_addr[6]    ← source
11   3A      PC[6]           ← U2.12 (QC)
12   4Y      A[7]            → ROM.3, RAM.3, bus connector
13   4B      data_addr[7]    ← source
14   4A      PC[7]           ← U2.11 (QD)
15   /E      GND             Always enabled
16   VCC     VCC             +5V
```

**A[15:8] routing (NO MUX available)**:
- During fetch (addr_sel=0): A[15:8] comes from U3-U4 (PC high byte)
- During data access (addr_sel=1): A[15:8] should come from U11 (ph) or $00 or $30

Since we have no mux for A[15:8], the 23-chip design uses this trick:
- A[15:8] is DIRECTLY driven by U3-U4 (PC high) at ALL times
- For data access, the instruction pre-sets PC high to the target page before access
- This means: pointer access requires ph value to be in PC high — NOT PRACTICAL

**Actual workable solution for 23 chips**:
- Limit data access to the SAME page as the current PC (code and data co-located)
- OR: tie A[15:8] to GND during data access via 8× pull-down resistors + addr_sel
  controlling U3-U4 output enable — but 74HC161 has no /OE!

**The design requires 2 more 74HC157 chips for A[15:8] mux. See final analysis.**

---

### U17: 74HC139 — Dual 2-to-4 Decoder

Decoder A: Instruction class decode (gated by S2)
Decoder B: Register write select (gated by write_en)

```
74HC139 pinout:
Pin  Name      Signal          Connect to
---  --------  -------------   ------------------------------------------
1    /Ea       S2_inv          ← NOT(S2) — active low enable; decoder active when S2=1
                                 Wire: /Q from (Q2 NAND /Q1) or use /S2 signal
2    A0a       ir_op[6]        ← U5.18 (class bit 0)
3    A1a       ir_op[7]        ← U5.19 (class bit 1)
4    /Y0a      class_00        → ALU class active (active low during S2)
5    /Y1a      class_01        → Load/Store class active
6    /Y2a      class_10        → Branch class active
7    /Y3a      class_11        → System class active
8    GND       GND             Ground
9    /Y3b      reg_sel_3       → (unused or sp_clk enable)
10   /Y2b      reg_sel_2       → t0_clk enable
11   /Y1b      reg_sel_1       → a0_clk enable (for LI a0)
12   /Y0b      reg_sel_0       → (unused)
13   A1b       ir_op[1]        ← U5.13 (register select bit 1)
14   A0b       ir_op[0]        ← U5.12 (register select bit 0)
15   /Eb       write_en_inv    ← NOT(write_en) — active when register write needed
16   VCC       VCC             +5V
```

Decoder A outputs (active low, only during S2):
- /Y0a = class_00 = ALU instruction executing
- /Y1a = class_01 = Load/Store executing
- /Y2a = class_10 = Branch executing
- /Y3a = class_11 = System executing

Decoder B outputs (active low, only when write_en asserted):
- /Y0b = reg_sel_0 = write to register 0 (a0 for ALU result)
- /Y1b = reg_sel_1 = write to register 1 (t0)
- /Y2b = reg_sel_2 = write to register 2 (sp)
- /Y3b = reg_sel_3 = write to register 3 (pl/ph)


---

### U18: 74HC74 — State Counter (2 flip-flops, ripple counter)

FF1 = state[0], FF2 = state[1]. Counts: 00→01→10→11→00 (S0→S1→S2→S3→S0).

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR1   /RST            Reset circuit (clears to state 00 = S0)
2    D1      /Q1             ← pin 6 (own /Q1 — toggle configuration)
3    CLK1    CLK             ← Master clock (3.5 MHz)
4    /PRE1   VCC             Tied high (no preset)
5    Q1      state[0]        → U20.1 (AND gate input), SYNC output
6    /Q1     /state[0]       → pin 2 (feedback for toggle), U20.4 (AND input)
7    GND     GND             Ground
8    /Q2     /state[1]       → U18.12 (feedback), pc_inc signal (=/RD)
9    Q2      state[1]        → U20.1(AND), U20.4(AND), U15.1+U16.1 (addr_sel)
10   /PRE2   VCC             Tied high
11   CLK2    /Q1             ← pin 6 (FF2 clocks on falling edge of Q1)
12   D2      /Q2             ← pin 8 (own /Q2 — toggle configuration)
13   /CLR2   /RST            Reset circuit
14   VCC     VCC             +5V
```

State truth table:
| Q2 | Q1 | State | Phase |
|:--:|:--:|:-----:|-------|
| 0  | 0  | S0    | Fetch opcode |
| 0  | 1  | S1    | Fetch operand |
| 1  | 0  | S2    | Execute |
| 1  | 1  | S3    | Memory access |

Key derived signals from state bits:
- `addr_sel` = Q2 (state[1]) — high during S2, S3 (data access phases)
- `pc_inc` = /Q2 (/state[1]) — high during S0, S1 (fetch phases)
- `/RD` = /Q2 — active (low) during S0, S1 (reading from memory)
- `ir_latch` = AND(Q1, /Q2) = S1 — opcode captured at S0→S1 edge
- `opr_latch` = AND(Q2, /Q1) = S2 — operand captured at S1→S2 edge
- `S2` = AND(Q2, /Q1)
- `S3` = AND(Q2, Q1)

### U19: 74HC74 — Flags (Z flag, C flag)

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    /CLR1   /RST            Reset circuit (clears Z=0)
2    D1      zero_detect     ← NOR of all ALU result bits (external logic needed)
3    CLK1    flags_we        ← U20.11 (AND: S2 AND class_00)
4    /PRE1   VCC             Tied high
5    Q1      flag_z          → U14.12 (XOR 4A) for branch condition select
6    /Q1     /flag_z         (available for inverted Z)
7    GND     GND             Ground
8    /Q2     /flag_c         (available for inverted C)
9    Q2      flag_c          → branch condition mux, carry_in logic
10   /PRE2   VCC             Tied high
11   CLK2    flags_we        ← U20.11 (same as CLK1 — both flags latch together)
12   D2      carry_out       ← U12.9 (C4 from high adder)
13   /CLR2   /RST            Reset circuit (clears C=0)
14   VCC     VCC             +5V
```

Note: `zero_detect` requires an 8-input NOR (or cascaded OR then invert).
With no spare gates, this needs external components:
- Option A: 8-input NOR from 2× 74HC32 (4 OR gates) + 1 inverter = too many chips
- Option B: Use a single 74HC688 (8-bit comparator) — adds 1 chip
- Option C: Cascade: OR(D0,D1) → OR(D2,D3) → OR(prev,prev) → OR(prev,prev) → invert
  Needs 4 OR gates (one 74HC32) + 1 inverter. But U21 is our only 74HC32!

**Practical solution**: Use 4 OR gates from U21 to build zero detect:
- U21.3 = OR(result[0], result[1])
- U21.6 = OR(result[2], result[3])
- U21.8 = OR(result[4], result[5])
- U21.11 = OR(result[6], result[7])
Then need OR(U21.3, U21.6) and OR(U21.8, U21.11) and final OR + invert.
This uses ALL 4 OR gates just for zero detect, leaving none for control!

**Honest answer**: Zero detect needs its own chip (74HC688 or 74HC02 NOR gates).
In the 23-chip budget, we sacrifice zero detect accuracy or steal gates.

**Workaround for 23 chips**: Use the ALU result bit 7 as a crude "non-zero" indicator
(only catches N flag), OR accept that Z flag only checks low nibble (4 bits via
cascaded NOR using spare inverters from other chips).

**This guide documents the IDEAL wiring assuming zero_detect is available.**

### U20: 74HC08 — AND Gates (Control Signal Generation)

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    1A      state[1]        ← U18.9 (Q2)
2    1B      /state[0]       ← U18.6 (/Q1)
3    1Y      S2              → U17.1 (/Ea inverted — see note), opr_latch
4    2A      state[1]        ← U18.9 (Q2)
5    2B      state[0]        ← U18.5 (Q1)
6    2Y      S3              → /WR logic, memory phase indicator
7    GND     GND             Ground
8    3Y      /WR             → RAM.27 (/WE pin)
9    3A      S3              ← pin 6 (U20.2Y)
10   3B      is_store        ← ir_op[4] (U5.16) — store ops have bit4=1
11   4Y      flags_we        → U19.3 (CLK1), U19.11 (CLK2)
12   4A      S2              ← pin 3 (U20.1Y)
13   4B      /class_00_inv   ← U17.4 (/Y0a) inverted — need inverter!
14   VCC     VCC             +5V
```

**Problem with pin 13**: U17 outputs are active-LOW. We need active-high class_00
for the AND gate. Options:
- Use a spare inverter (none available in 23-chip budget)
- Restructure: use NAND logic instead (74HC00 instead of 74HC08)
- Use the /Y0a output with a NOR gate configuration

**Practical fix**: Change U20 gate 4 to: flags_we = S2 NAND /class_00 (active low).
Since U19 CLK triggers on rising edge, we need flags_we to pulse HIGH.
Use: flags_we = NOT(/Y0a) AND S2. The NOT comes from... nowhere spare.

**Alternative**: Wire U17 /Ea = /S2 (inverted S2). Then /Y0a goes low ONLY during
S2 AND class_00. Use /Y0a directly as an active-low flags_we — but 74HC74 CLK
needs a rising edge, not active-low level. Use the FALLING edge of /Y0a at end of S2.

**This is getting complex. The guide documents the LOGICAL intent; physical
implementation may need gate substitution (e.g., 74HC00 NAND instead of 74HC08 AND).**

### U21: 74HC32 — OR Gates (Control Signal Combining)

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    1A      alu_write       ← S2 AND class_00 (from U20 or decode)
2    1B      mem_load        ← S3 AND is_load (load complete signal)
3    1Y      a0_clk          → U7.11 (a0 register CLK)
4    2A      /state[1]       ← U18.8 (/Q2) — high during S0,S1
5    2B      S3_and_load     ← (S3 AND is_load) for read during mem phase
6    2Y      /RD             → ROM.22 (/OE), RAM.22 (/OE)
7    GND     GND             Ground
8    3Y      pc_inc          → U1.7+10, U2.7+10, U3.7+10, U4.7+10
9    3A      /state[1]       ← U18.8 (/Q2) — PC increments during fetch
10   3B      GND             (OR with 0 = pass-through of /Q2)
11   4Y      ir_latch        → U5.11 (IR opcode register CLK)
12   4A      /state[0]       ← U18.6 (/Q1)
13   4B      state[1]        ← U18.9 (Q2) — NOT CORRECT for ir_latch
14   VCC     VCC             +5V
```

**Revised gate 3**: pc_inc = /Q2 directly (no OR needed, just wire /Q2 to PC enables).
Free up gate 3 for something else.

**Revised gate 4**: ir_latch needs to be a pulse at S0→S1 transition.
Using AND(Q1, /Q2) = S1 signal. But this is an AND, not OR.
Move ir_latch generation to U20 (AND gates).

**Revised U21 allocation:**
```
Gate 1: a0_clk = alu_write OR mem_load
Gate 2: /RD = /Q2 OR (S3 AND is_load)  — read during fetch OR load phase
Gate 3: (spare — use for zero detect partial)
Gate 4: (spare — use for zero detect partial)
```


---

### ROM: AT28C256 — Program ROM (32KB)

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    A14     A[14]           ← U4.12 (QC) via address bus
2    A12     A[12]           ← U4.14 (QA) via address bus
3    A7      A[7]            ← U16.12 (4Y) via address bus
4    A6      A[6]            ← U16.9 (3Y) via address bus
5    A5      A[5]            ← U16.7 (2Y) via address bus
6    A4      A[4]            ← U16.4 (1Y) via address bus
7    A3      A[3]            ← U15.12 (4Y) via address bus
8    A2      A[2]            ← U15.9 (3Y) via address bus
9    A1      A[1]            ← U15.7 (2Y) via address bus
10   A0      A[0]            ← U15.4 (1Y) via address bus
11   D0      D[0]            ↔ Data bus bit 0
12   D1      D[1]            ↔ Data bus bit 1
13   D2      D[2]            ↔ Data bus bit 2
14   GND     GND             Ground
15   D3      D[3]            ↔ Data bus bit 3
16   D4      D[4]            ↔ Data bus bit 4
17   D5      D[5]            ↔ Data bus bit 5
18   D6      D[6]            ↔ Data bus bit 6
19   D7      D[7]            ↔ Data bus bit 7
20   /CE     /ROM_CE         ← A[15] inverted (ROM selected when A15=1, addr $8000-$FFFF)
21   A10     A[10]           ← U3.12 (QC) via address bus
22   /OE     /RD             ← U18.8 (/Q2) or U21.6 — active during read
23   A11     A[11]           ← U3.11 (QD) via address bus
24   A9      A[9]            ← U3.13 (QB) via address bus
25   A8      A[8]            ← U3.14 (QA) via address bus
26   A13     A[13]           ← U4.13 (QB) via address bus
27   /WE     VCC             Tied high (no writes to ROM in normal operation)
28   VCC     VCC             +5V
```

/ROM_CE generation: A[15] = 1 means ROM space ($8000-$FFFF).
Simple: /ROM_CE = NOT(A[15]). Use a spare inverter or:
- Tie /CE to NOT(A15) using a transistor + resistor
- Or use one gate from U20/U21 configured as inverter (tie both inputs together for OR=buffer, not invert)
- **Best**: Use A[15] directly — ROM /CE = GND (always enabled), rely on /OE for output control. ROM only drives bus when /OE is low (during read phases). Since A[15] from PC is always 1 during fetch (code at $C000+), this works if RAM is disabled during fetch.

### RAM: 62256 — Data RAM (32KB)

```
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    A14     A[14]           ← address bus
2    A12     A[12]           ← address bus
3    A7      A[7]            ← address bus
4    A6      A[6]            ← address bus
5    A5      A[5]            ← address bus
6    A4      A[4]            ← address bus
7    A3      A[3]            ← address bus
8    A2      A[2]            ← address bus
9    A1      A[1]            ← address bus
10   A0      A[0]            ← address bus
11   D0      D[0]            ↔ Data bus bit 0
12   D1      D[1]            ↔ Data bus bit 1
13   D2      D[2]            ↔ Data bus bit 2
14   GND     GND             Ground
15   D3      D[3]            ↔ Data bus bit 3
16   D4      D[4]            ↔ Data bus bit 4
17   D5      D[5]            ↔ Data bus bit 5
18   D6      D[6]            ↔ Data bus bit 6
19   D7      D[7]            ↔ Data bus bit 7
20   /CE     /RAM_CE         ← A[15] directly (RAM selected when A15=0, addr $0000-$7FFF)
21   A10     A[10]           ← address bus
22   /OE     /RD             ← same as ROM /OE (active during read)
23   A11     A[11]           ← address bus
24   A9      A[9]            ← address bus
25   A8      A[8]            ← address bus
26   A13     A[13]           ← address bus
27   /WE     /WR             ← U20.8 (AND: S3 AND is_store)
28   VCC     VCC             +5V
```

Memory map:
- $0000-$7FFF: RAM (32KB) — zero-page at $00xx, stack at $00xx (23-chip version)
- $8000-$FFFF: ROM (32KB) — code starts at $C000

---

### Crystal Oscillator — 3.5 MHz

```
Component: 3.5 MHz crystal oscillator module (4-pin DIP)
Pin  Name    Signal          Connect to
---  ------  -------------   ------------------------------------------
1    NC      —               No connect (or GND on some modules)
7    GND     GND             Ground
8    OUT     CLK             → U18.3 (state counter CLK)
                              → U1.2, U2.2, U3.2, U4.2 (PC CLK)
                              → U10.2, U11.2 (pointer CLK)
                              → LED17 via 330R (CLK indicator)
14   VCC     VCC             +5V
```

Note: If using a crystal + 2 caps + inverter (not module), you need a 74HC04
inverter chip — adds 1 chip. The oscillator module is self-contained.

### Reset Circuit

```
Components:
- R1: 10KΩ pull-up (VCC to /RST line)
- C1: 100nF capacitor (/RST to GND)
- SW1: Pushbutton (normally open, /RST to GND when pressed)

Schematic:
  VCC ──[10K]──┬── /RST bus signal
               │
              [100nF]
               │
  GND ─────────┴──[SW1]── GND

/RST connects to:
  - U1.1, U2.1, U3.1, U4.1 (/CLR on PC counters)
  - U10.1, U11.1 (/CLR on pointer counters)
  - U18.1, U18.13 (/CLR on state counter FFs)
  - U19.1, U19.13 (/CLR on flag FFs)
  - LED18 via 330R (active-low, LED on during reset)
```

Power-on: C1 holds /RST low for ~1ms (RC time constant = 10K × 100nF = 1ms),
then /RST rises to VCC. All counters and FFs start at 0.

---

### LEDs (18 total)

```
LED1-LED8: Data bus D[7:0] indicators
  D[0] ──[330R]──[LED1]── GND
  D[1] ──[330R]──[LED2]── GND
  D[2] ──[330R]──[LED3]── GND
  D[3] ──[330R]──[LED4]── GND
  D[4] ──[330R]──[LED5]── GND
  D[5] ──[330R]──[LED6]── GND
  D[6] ──[330R]──[LED7]── GND
  D[7] ──[330R]──[LED8]── GND

LED9-LED16: Address bus A[7:0] indicators
  A[0] ──[330R]──[LED9]── GND
  A[1] ──[330R]──[LED10]── GND
  A[2] ──[330R]──[LED11]── GND
  A[3] ──[330R]──[LED12]── GND
  A[4] ──[330R]──[LED13]── GND
  A[5] ──[330R]──[LED14]── GND
  A[6] ──[330R]──[LED15]── GND
  A[7] ──[330R]──[LED16]── GND

LED17: CLK indicator
  CLK ──[330R]──[LED17]── GND
  (At 3.5 MHz this LED appears always-on; useful for detecting halt/no-clock)

LED18: /RST indicator (active-low: LED ON during reset)
  /RST ──[330R]──[LED18]── VCC  (LED between /RST and VCC, lights when /RST=LOW)
```

---

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
29   /RD         30   /WR
31   /ROM_CE     32   /RAM_CE
33   /IO_CE      34   SYNC
35   HALT        36   /NMI
37   /IRQ        38   addr_sel
39   state[0]    40   state[1]
```

---

### Power Connections (VCC/GND for every chip)

| Chip | VCC Pin | GND Pin | Package |
|------|:-------:|:-------:|---------|
| U1 (74HC161) | 16 | 8 | DIP-16 |
| U2 (74HC161) | 16 | 8 | DIP-16 |
| U3 (74HC161) | 16 | 8 | DIP-16 |
| U4 (74HC161) | 16 | 8 | DIP-16 |
| U5 (74HC574) | 20 | 10 | DIP-20 |
| U6 (74HC574) | 20 | 10 | DIP-20 |
| U7 (74HC574) | 20 | 10 | DIP-20 |
| U8 (74HC574) | 20 | 10 | DIP-20 |
| U9 (74HC574) | 20 | 10 | DIP-20 |
| U10 (74HC161) | 16 | 8 | DIP-16 |
| U11 (74HC161) | 16 | 8 | DIP-16 |
| U12 (74HC283) | 16 | 8 | DIP-16 |
| U13 (74HC283) | 16 | 8 | DIP-16 |
| U14 (74HC86) | 14 | 7 | DIP-14 |
| U15 (74HC157) | 16 | 8 | DIP-16 |
| U16 (74HC157) | 16 | 8 | DIP-16 |
| U17 (74HC139) | 16 | 8 | DIP-16 |
| U18 (74HC74) | 14 | 7 | DIP-14 |
| U19 (74HC74) | 14 | 7 | DIP-14 |
| U20 (74HC08) | 14 | 7 | DIP-14 |
| U21 (74HC32) | 14 | 7 | DIP-14 |
| ROM (AT28C256) | 28 | 14 | DIP-28 |
| RAM (62256) | 28 | 14 | DIP-28 |

**Bypass capacitors**: 100nF ceramic capacitor between VCC and GND at EVERY chip,
placed as close to the chip as possible. Total: 23× 100nF.


---

## FINAL ANALYSIS: Does It Fit in 23 Chips?

### Problems Identified During Pin-Level Trace

| # | Problem | Impact | Fix |
|:-:|---------|--------|-----|
| 1 | **Address mux A[15:8]**: No mux for high byte. During data access, need to route ph/00/30 to A[15:8] instead of PC high. 74HC161 has no /OE pin. | Cannot access RAM at different page than PC | Add 2× 74HC157 |
| 2 | **ALU B-input XOR**: Only 4 XOR gates (U14) but need 8 for full 8-bit SUB. Gate 4 used for branch condition. | SUB/SBC/CMP broken for bits 3-7 | Add 1× 74HC86 |
| 3 | **ALU B-source mux**: Need to select between t0 and operand for ALU B input (8 bits). No mux available. | Cannot do register-mode ALU ops | Add 2× 74HC157 |
| 4 | **Address mux B-source**: Three sources (pl, operand, sp) share B inputs of U15-U16. Need sub-mux. | Cannot do zero-page AND pointer AND stack | Add 2× 74HC157 |
| 5 | **Zero detect**: Need 8-input NOR for Z flag. No spare gates. | Z flag doesn't work | Add 1× 74HC02 or 74HC688 |
| 6 | **Inverters**: Several signals need inversion (A15 for /ROM_CE, /Y0a for flags_we, etc). No inverter chip. | Control signals broken | Add 1× 74HC04 |
| 7 | **ALU result to data bus**: ALU outputs need to drive data bus during S2, but bus is shared with ROM/RAM. Need tri-state buffer or careful /OE timing. | Bus contention | Timing-resolved (ROM /OE off during S2) |

### Honest Chip Count

| Category | 23-chip spec | Actually needed |
|----------|:------------:|:---------------:|
| PC (16-bit counter) | 4× 74HC161 | 4× 74HC161 ✓ |
| Registers (IR, a0, t0, sp) | 5× 74HC574 | 5× 74HC574 ✓ |
| Pointer (pl, ph) | 2× 74HC161 | 2× 74HC161 ✓ |
| ALU adder | 2× 74HC283 | 2× 74HC283 ✓ |
| ALU XOR (SUB invert) | 1× 74HC86 | **2× 74HC86** ✗ |
| Address mux (low byte) | 2× 74HC157 | 2× 74HC157 ✓ |
| Address mux (high byte) | (not in spec) | **2× 74HC157** ✗ |
| ALU B-source mux | (not in spec) | **2× 74HC157** ✗ |
| Decoder | 1× 74HC139 | 1× 74HC139 ✓ |
| State counter | 1× 74HC74 | 1× 74HC74 ✓ |
| Flags | 1× 74HC74 | 1× 74HC74 ✓ |
| AND gates | 1× 74HC08 | 1× 74HC08 ✓ |
| OR gates | 1× 74HC32 | 1× 74HC32 ✓ |
| Inverters | (not in spec) | **1× 74HC04** ✗ |
| Zero detect | (not in spec) | **1× 74HC688** ✗ |
| ROM | 1× AT28C256 | 1× AT28C256 ✓ |
| RAM | 1× 62256 | 1× 62256 ✓ |
| **TOTAL** | **23** | **30** |

### What CAN Fit in 23 Chips (Reduced Functionality)

To actually fit in 23 chips, accept these limitations:

1. **No high-byte address mux** → All data access in same 256-byte page as code (or page $00 only)
2. **4-bit SUB only** → SUB works correctly only for values 0-15 (low nibble XOR'd, high nibble raw)
3. **Immediate-only ALU** → Remove register mode (t0 not routed to ALU B, only operand)
4. **Single address source** → Pointer only (no zero-page or stack addressing)
5. **No Z flag** → Only C and N flags available (branch on carry/negative only)
6. **Hardwired /ROM_CE** → ROM always at $8000+ via A[15] direct to /CE

With these limitations, the 23-chip design IS buildable and can run simple programs
(loops, arithmetic, pointer-based memory access) but CANNOT run BASIC or complex software.

### Recommended Minimum for Full Functionality: 27 chips

```
23 (base) + 1 (74HC86 for full SUB) + 2 (74HC157 for high addr mux) + 1 (74HC04 inverters) = 27
```

This matches the original RV8 design (27 chips with EEPROM microcode). The "gates-only"
approach trades the EEPROM for additional mux/logic chips — roughly the same total.

### The 23-Chip Sweet Spot (Practical Compromise)

If you MUST stay at 23 chips, the best compromise is:

1. Replace U14 (74HC86) with 74HC240 (octal inverting buffer with /OE) — gives 8 inverters for SUB + tri-state for bus driving. Loses branch XOR but branch can use AND/OR from U20/U21.
2. Accept pointer-only addressing (no zero-page, no stack page $30 — stack at $00xx)
3. Accept that A[15:8] during data access = $00 (all data in first 256 bytes of RAM, or use pointer ph register loaded into PC high before access — software workaround)

This gives a WORKING 23-chip CPU that can run simple programs with the understanding
that the Verilog model (which has unlimited "wires") implements features that require
more physical chips to realize in hardware.

---

## Summary

This wiring guide documents the RV8-G design at pin level. The Verilog simulation
(rv8g_cpu.v) is correct and complete. The physical implementation in 23 74HC chips
requires accepting limitations in addressing modes and ALU operations, OR expanding
to ~27 chips for full functionality.

The core architecture (4-state machine, opcode-bits-as-control, 2-byte fixed instructions)
is sound and elegant. The chip count pressure comes from the MULTIPLEXING problem:
a shared-bus architecture needs many mux points that are "free" in Verilog but cost
physical chips in hardware.

**Recommendation**: Build with 25 chips (add 1× 74HC86 + 1× 74HC157 for high address)
as the minimum viable hardware that matches the Verilog behavior for most instructions.
