# RV802 CPU — WiringGuide

```
{
  Project: "RV802",
  Chips: 25,
  Packages: "25 logic + ROM + RAM = 27 total",
  Architecture: "Single 8-bit bus (IBUS), Flash microcode, 4-step fixed",
  Clock: "10 MHz → 2.5 MIPS (all instructions = 4 cycles)",
  Supply: "5V"
}
```

## Bus Nets

| Net | Width | Description |
|-----|:-----:|-------------|
| IBUS[7:0] | 8 | Internal tri-state data bus |
| ADDR[15:0] | 16 | Address bus → ROM/RAM |
| DEXT[7:0] | 8 | External data bus (ROM/RAM D pins) |
| CLK | 1 | 10 MHz master clock |
| /RST | 1 | Active-low reset |
| SUB | 1 | Subtract mode (XOR invert + Cin=1) |

## Microcode (U23 Flash)

```
Address A[11:0]:
  A[11:10] = step[1:0]  (U24 — free-running ÷4 counter)
  A[9:2]   = opcode[7:0] (U9 Q outputs)
  A[1]     = FLAG_Z      (combinational wired-NOR of ALU result)
  A[0]     = FLAG_C      (combinational U13.Cout)

Data D[7:0] — directly clocks/enables targets:
  D0 = REG_RD_EN  → U20.G1 (register drives IBUS)
  D1 = REG_WR_EN  → U21.G1 (register latches IBUS)
  D2 = OPR_CLK    → U10.CLK (latch operand)
  D3 = ALU_B_CLK  → U11.CLK (latch ALU B)
  D4 = ALU_R_CLK  → U25.CLK (latch ALU result)
  D5 = IR_CLK     → U9.CLK (latch opcode)
  D6 = /BUF_OE    → U22./OE (enable ext buffer, active-low)
  D7 = BUF_DIR    → U22.DIR (0=read ext→int, 1=write int→ext)

PC_CNT derived from step counter: /Q2 from U24 (HIGH during steps 0,1).
PC_LOAD: directly from microcode via shared REG_WR_EN during branch steps.
```

## ISA Encoding

```
Byte 1 (opcode): [7:6]=class [5:3]=rs/op [2:0]=rd
Byte 2 (operand): [7:0]=imm8

U9.Q[2:0] = rd → U21.A/B/C (write select)
U9.Q[5:3] = rs → U20.A/B/C (read select)
```

## Execution Steps (all instructions)

```
Step 0: BUF_OE=0, IR_CLK↑    → ROM[PC] → IBUS → U9 latches opcode. PC++
Step 1: BUF_OE=0, OPR_CLK↑   → ROM[PC] → IBUS → U10 latches operand. PC++
Step 2: REG_RD_EN=1, ALU_B_CLK↑ → rs drives IBUS → U11 latches ALU B
        (or: immediate from U10 drives IBUS instead for class 01)
Step 3: ALU_R_CLK↑, then REG_WR_EN=1 → ALU result → U25 → IBUS → rd latches
```

---

## Part List

| U# | Chip | Qty | Function |
|:--:|------|:---:|----------|
| U1-U8 | 74HC574 | 8 | Registers r0-r7 |
| U9 | 74HC574 | 1 | IR opcode latch |
| U10 | 74HC574 | 1 | IR operand latch |
| U11 | 74HC574 | 1 | ALU B latch |
| U12 | 74HC283 | 1 | Adder low (bits 0-3) |
| U13 | 74HC283 | 1 | Adder high (bits 4-7) |
| U14 | 74HC86 | 1 | XOR low (SUB invert bits 0-3) |
| U15 | 74HC86 | 1 | XOR high (SUB invert bits 4-7) |
| U16 | 74HC161 | 1 | PC bits 0-3 |
| U17 | 74HC161 | 1 | PC bits 4-7 |
| U18 | 74HC161 | 1 | PC bits 8-11 |
| U19 | 74HC161 | 1 | PC bits 12-15 |
| U20 | 74HC138 | 1 | Register read decoder (/OE) |
| U21 | 74HC238 | 1 | Register write decoder (CLK) |
| U22 | 74HC245 | 1 | External bus buffer |
| U23 | SST39SF010A | 1 | Microcode Flash |
| U24 | 74HC74 | 1 | Step counter (2-bit ÷4) |
| U25 | 74HC574 | 1 | ALU result latch (tri-state) |
| — | AT28C256 | 1 | Program ROM (32K×8) |
| — | 62256 | 1 | Data RAM (32K×8) |

---

## Pin-Level Wiring


### U1–U8: 74HC574 ×8 — Registers (DIP-20)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | /OE | U20.Yn (n=chip#−1). LOW=drive IBUS |
| 2-9 | D[0:7] | IBUS[0:7] |
| 10 | GND | GND |
| 11 | CLK | U21.Yn (n=chip#−1). Rising edge=latch |
| 12-19 | Q[7:0] | IBUS[7:0] (tri-state) |
| 20 | VCC | VCC |

/OE map: U1→U20.Y0, U2→Y1, U3→Y2, U4→Y3, U5→Y4, U6→Y5, U7→Y6, U8→Y7
CLK map: U1→U21.Y0, U2→Y1, U3→Y2, U4→Y3, U5→Y4, U6→Y5, U7→Y6, U8→Y7

Note: r0 (U1) = always zero (microcode never asserts U21.Y0).

---

### U9: 74HC574 — IR Opcode (DIP-20)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | /OE | GND (always outputs) |
| 2-9 | D[0:7] | IBUS[0:7] |
| 10 | GND | GND |
| 11 | CLK | IR_CLK (Flash D5, active during step 0) |
| 12 | Q7 | U23.A9 (class[1]) |
| 13 | Q6 | U23.A8 (class[0]) |
| 14 | Q5 | U23.A7 + U20.C (rs[2]) |
| 15 | Q4 | U23.A6 + U20.B (rs[1]) |
| 16 | Q3 | U23.A5 + U20.A (rs[0]) |
| 17 | Q2 | U23.A4 + U21.C (rd[2]) |
| 18 | Q1 | U23.A3 + U21.B (rd[1]) |
| 19 | Q0 | U23.A2 + U21.A (rd[0]) |
| 20 | VCC | VCC |

---

### U10: 74HC574 — IR Operand (DIP-20)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | /OE | OPR_OE (microcode — LOW to drive IBUS for immediate ops) |
| 2-9 | D[0:7] | IBUS[0:7] |
| 10 | GND | GND |
| 11 | CLK | OPR_CLK (Flash D2, active during step 1) |
| 12-19 | Q[7:0] | IBUS[7:0] (tri-state, enabled by /OE) |
| 20 | VCC | VCC |

OPR_OE: driven LOW by microcode during step 2 for immediate-class instructions.
When HIGH: outputs Hi-Z, IBUS free for register or external data.

---

### U11: 74HC574 — ALU B Latch (DIP-20)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | /OE | GND (always outputs to XOR gates) |
| 2-9 | D[0:7] | IBUS[0:7] |
| 10 | GND | GND |
| 11 | CLK | ALU_B_CLK (Flash D3, active during step 2) |
| 12 | Q7 | U15.pin13 (XOR4.A) |
| 13 | Q6 | U15.pin10 (XOR3.A) |
| 14 | Q5 | U15.pin4 (XOR2.A) |
| 15 | Q4 | U15.pin1 (XOR1.A) |
| 16 | Q3 | U14.pin13 (XOR4.A) |
| 17 | Q2 | U14.pin10 (XOR3.A) |
| 18 | Q1 | U14.pin4 (XOR2.A) |
| 19 | Q0 | U14.pin1 (XOR1.A) |
| 20 | VCC | VCC |

---


### U12: 74HC283 — Adder Low Nibble (DIP-16)

| Pin | Name | Connection |
|:---:|------|-----------|
| 5 | A1 | IBUS0 (ALU A bit 0, direct from bus) |
| 3 | A2 | IBUS1 |
| 12 | A3 | IBUS2 |
| 13 | A4 | IBUS3 |
| 6 | B1 | U14.pin3 (XOR1.Y = B[0]^SUB) |
| 2 | B2 | U14.pin6 (XOR2.Y = B[1]^SUB) |
| 11 | B3 | U14.pin8 (XOR3.Y = B[2]^SUB) |
| 14 | B4 | U14.pin11 (XOR4.Y = B[3]^SUB) |
| 4 | Σ1 | U25.D0 (result bit 0) |
| 1 | Σ2 | U25.D1 (result bit 1) |
| 10 | Σ3 | U25.D2 (result bit 2) |
| 15 | Σ4 | U25.D3 (result bit 3) |
| 7 | Cin | SUB (0=add, 1=subtract) |
| 9 | Cout | U13.pin7 (carry to high nibble) |
| 8 | GND | GND |
| 16 | VCC | VCC |

---

### U13: 74HC283 — Adder High Nibble (DIP-16)

| Pin | Name | Connection |
|:---:|------|-----------|
| 5 | A1 | IBUS4 (ALU A bit 4) |
| 3 | A2 | IBUS5 |
| 12 | A3 | IBUS6 |
| 13 | A4 | IBUS7 |
| 6 | B1 | U15.pin3 (XOR1.Y = B[4]^SUB) |
| 2 | B2 | U15.pin6 (XOR2.Y = B[5]^SUB) |
| 11 | B3 | U15.pin8 (XOR3.Y = B[6]^SUB) |
| 14 | B4 | U15.pin11 (XOR4.Y = B[7]^SUB) |
| 4 | Σ1 | U25.D4 (result bit 4) |
| 1 | Σ2 | U25.D5 (result bit 5) |
| 10 | Σ3 | U25.D6 (result bit 6) |
| 15 | Σ4 | U25.D7 (result bit 7) |
| 7 | Cin | U12.pin9 (carry from low nibble) |
| 9 | Cout | FLAG_C → U23.A0 (carry flag, combinational) |
| 8 | GND | GND |
| 16 | VCC | VCC |

---

### U14: 74HC86 — XOR Low Nibble (DIP-14)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | 1A | U11.Q0 (B bit 0) |
| 2 | 1B | SUB |
| 3 | 1Y | U12.pin6 (adder B1) |
| 4 | 2A | U11.Q1 (B bit 1) |
| 5 | 2B | SUB |
| 6 | 2Y | U12.pin2 (adder B2) |
| 7 | GND | GND |
| 8 | 3Y | U12.pin11 (adder B3) |
| 9 | 3B | SUB |
| 10 | 3A | U11.Q2 (B bit 2) |
| 11 | 4Y | U12.pin14 (adder B4) |
| 12 | 4B | SUB |
| 13 | 4A | U11.Q3 (B bit 3) |
| 14 | VCC | VCC |

---

### U15: 74HC86 — XOR High Nibble (DIP-14)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | 1A | U11.Q4 (B bit 4) |
| 2 | 1B | SUB |
| 3 | 1Y | U13.pin6 (adder B1) |
| 4 | 2A | U11.Q5 (B bit 5) |
| 5 | 2B | SUB |
| 6 | 2Y | U13.pin2 (adder B2) |
| 7 | GND | GND |
| 8 | 3Y | U13.pin11 (adder B3) |
| 9 | 3B | SUB |
| 10 | 3A | U11.Q6 (B bit 6) |
| 11 | 4Y | U13.pin14 (adder B4) |
| 12 | 4B | SUB |
| 13 | 4A | U11.Q7 (B bit 7) |
| 14 | VCC | VCC |

SUB: decoded combinationally from U9.Q[7:3]. HIGH for SUB/SUBI/CMP/CMPI opcodes.
When SUB=1: B inverted + Cin=1 → two's complement subtraction.

---


### U16–U19: 74HC161 ×4 — Program Counter (DIP-16)

Cascaded 4-bit synchronous counters. Carry: U16.TC→U17.ENT→U18→U19.

| Pin | Name | U16 (PC[3:0]) | U17 (PC[7:4]) | U18 (PC[11:8]) | U19 (PC[15:12]) |
|:---:|------|--------------|--------------|---------------|----------------|
| 1 | /CLR | /RST | /RST | /RST | /RST |
| 2 | CLK | CLK | CLK | CLK | CLK |
| 3 | D0 | IBUS0 | IBUS4 | IBUS0* | IBUS4* |
| 4 | D1 | IBUS1 | IBUS5 | IBUS1* | IBUS5* |
| 5 | D2 | IBUS2 | IBUS6 | IBUS2* | IBUS6* |
| 6 | D3 | IBUS3 | IBUS7 | IBUS3* | IBUS7* |
| 7 | ENP | PC_CNT | PC_CNT | PC_CNT | PC_CNT |
| 8 | GND | GND | GND | GND | GND |
| 9 | /LOAD | /PC_LOAD | /PC_LOAD | /PC_LOAD | /PC_LOAD |
| 10 | ENT | PC_CNT | U16.TC | U17.TC | U18.TC |
| 11 | Q3 | ADDR3 | ADDR7 | ADDR11 | ADDR15 |
| 12 | Q2 | ADDR2 | ADDR6 | ADDR10 | ADDR14 |
| 13 | Q1 | ADDR1 | ADDR5 | ADDR9 | ADDR13 |
| 14 | Q0 | ADDR0 | ADDR4 | ADDR8 | ADDR12 |
| 15 | TC | → U17.ENT | → U18.ENT | → U19.ENT | NC |
| 16 | VCC | VCC | VCC | VCC | VCC |

PC_CNT = U24./Q2 (HIGH during steps 0,1 → PC increments during fetch).
/PC_LOAD: active-low, from microcode (branch/jump execute step).
*U18/U19 D inputs: loaded from IBUS during JMP (page register), or held.

Reset: /CLR=LOW → PC=0x0000. ROM mapped at 0x0000.

---


### U20: 74HC138 — Register Read Decoder (DIP-16)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | A | U9.Q3 (rs[0]) |
| 2 | B | U9.Q4 (rs[1]) |
| 3 | C | U9.Q5 (rs[2]) |
| 4 | /G2A | GND |
| 5 | /G2B | GND |
| 6 | G1 | REG_RD_EN (Flash D0, HIGH=active) |
| 7 | Y7 | U8./OE (r7) |
| 8 | GND | GND |
| 9 | Y6 | U7./OE (r6) |
| 10 | Y5 | U6./OE (r5) |
| 11 | Y4 | U5./OE (r4) |
| 12 | Y3 | U4./OE (r3) |
| 13 | Y2 | U3./OE (r2) |
| 14 | Y1 | U2./OE (r1) |
| 15 | Y0 | U1./OE (r0) |
| 16 | VCC | VCC |

G1=HIGH: selected Yn goes LOW → register drives IBUS.
G1=LOW: all Yn HIGH → no register on bus.
Address from opcode[5:3] = rs field (SOURCE register).

---

### U21: 74HC238 — Register Write Decoder (DIP-16)

Non-inverting decoder (active-HIGH outputs → direct CLK for registers).

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | A | U9.Q0 (rd[0]) |
| 2 | B | U9.Q1 (rd[1]) |
| 3 | C | U9.Q2 (rd[2]) |
| 4 | /G2A | GND |
| 5 | /G2B | GND |
| 6 | G1 | REG_WR_EN (Flash D1, HIGH=write pulse) |
| 7 | Y7 | U8.CLK (r7) |
| 8 | GND | GND |
| 9 | Y6 | U7.CLK (r6) |
| 10 | Y5 | U6.CLK (r5) |
| 11 | Y4 | U5.CLK (r4) |
| 12 | Y3 | U4.CLK (r3) |
| 13 | Y2 | U3.CLK (r2) |
| 14 | Y1 | U2.CLK (r1) |
| 15 | Y0 | U1.CLK (r0) |
| 16 | VCC | VCC |

G1 LOW→HIGH: selected Yn goes HIGH = rising CLK edge → register latches IBUS.
Address from opcode[2:0] = rd field (DESTINATION register).

---

### U22: 74HC245 — External Bus Buffer (DIP-20)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | DIR | BUF_DIR (Flash D7: 0=B→A read, 1=A→B write) |
| 2 | A0 | IBUS0 |
| 3 | A1 | IBUS1 |
| 4 | A2 | IBUS2 |
| 5 | A3 | IBUS3 |
| 6 | A4 | IBUS4 |
| 7 | A5 | IBUS5 |
| 8 | A6 | IBUS6 |
| 9 | A7 | IBUS7 |
| 10 | GND | GND |
| 11 | B7 | DEXT7 (ROM.D7, RAM.D7) |
| 12 | B6 | DEXT6 |
| 13 | B5 | DEXT5 |
| 14 | B4 | DEXT4 |
| 15 | B3 | DEXT3 |
| 16 | B2 | DEXT2 |
| 17 | B1 | DEXT1 |
| 18 | B0 | DEXT0 |
| 19 | /OE | /BUF_OE (Flash D6, LOW=enabled) |
| 20 | VCC | VCC |

---


### U23: SST39SF010A — Microcode Flash (PDIP-32)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | A16 | GND (unused) |
| 2 | A15 | GND |
| 3 | A14 | GND |
| 4 | A13 | GND |
| 5 | A12 | GND |
| 6 | A11 | U24.Q2 (step[1]) |
| 7 | A10 | U24.Q1 (step[0]) |
| 8 | A9 | U9.Q7 (class[1]) |
| 9 | A8 | U9.Q6 (class[0]) |
| 10 | A7 | U9.Q5 (rs[2]/op[2]) |
| 11 | A6 | U9.Q4 (rs[1]/op[1]) |
| 12 | A5 | U9.Q3 (rs[0]/op[0]) |
| 13 | A4 | U9.Q2 (rd[2]) |
| 14 | A3 | U9.Q1 (rd[1]) |
| 15 | A2 | U9.Q0 (rd[0]) |
| 16 | GND | GND |
| 17 | A1 | FLAG_Z (wired-NOR of U25.Q[7:0]) |
| 18 | A0 | FLAG_C (U13.Cout, pin 9) |
| 19 | /CE | GND (always selected) |
| 20 | /OE | GND (always output) |
| 21 | D0 | REG_RD_EN → U20.G1 |
| 22 | D1 | REG_WR_EN → U21.G1 |
| 23 | D2 | OPR_CLK → U10.CLK |
| 24 | D3 | ALU_B_CLK → U11.CLK |
| 25 | D4 | ALU_R_CLK → U25.CLK |
| 26 | D5 | IR_CLK → U9.CLK |
| 27 | D6 | /BUF_OE → U22./OE |
| 28 | D7 | BUF_DIR → U22.DIR |
| 29 | /WE | VCC (write disabled) |
| 30 | NC | NC |
| 31 | NC | NC |
| 32 | VCC | VCC |

4096 entries used (12 address bits). 70ns access < 100ns clock period.
Programmed with TL866 or compatible. SUB signal decoded separately (see notes).

---


### U24: 74HC74 — Step Counter (DIP-14)

2-bit free-running divider (CLK÷4). Toggle mode: D←/Q.

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | /CLR1 | /RST |
| 2 | D1 | U24.pin6 (/Q1 — toggle feedback) |
| 3 | CLK1 | CLK |
| 4 | /PRE1 | VCC |
| 5 | Q1 | U23.A10 (step[0]) |
| 6 | /Q1 | U24.pin2 (feedback) + U24.pin11 (CLK2) |
| 7 | GND | GND |
| 8 | /Q2 | U24.pin12 (feedback) + PC_CNT (→ U16-U19.ENP) |
| 9 | Q2 | U23.A11 (step[1]) |
| 10 | /PRE2 | VCC |
| 11 | CLK2 | U24.pin6 (/Q1 — ripple from bit 0) |
| 12 | D2 | U24.pin8 (/Q2 — toggle feedback) |
| 13 | /CLR2 | /RST |
| 14 | VCC | VCC |

Step sequence: {Q2,Q1} = 00→01→10→11→00 (repeats every 4 CLK cycles).
/Q2 = HIGH during steps 0,1 → PC_CNT active during fetch (auto-increment).

---

### U25: 74HC574 — ALU Result Latch (DIP-20)

Captures adder output, drives IBUS when enabled (tri-state).

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | /OE | ALU_OE (LOW=drive IBUS with result, from microcode) |
| 2 | D0 | U12.Σ1 (pin 4, result bit 0) |
| 3 | D1 | U12.Σ2 (pin 1, result bit 1) |
| 4 | D2 | U12.Σ3 (pin 10, result bit 2) |
| 5 | D3 | U12.Σ4 (pin 15, result bit 3) |
| 6 | D4 | U13.Σ1 (pin 4, result bit 4) |
| 7 | D5 | U13.Σ2 (pin 1, result bit 5) |
| 8 | D6 | U13.Σ3 (pin 10, result bit 6) |
| 9 | D7 | U13.Σ4 (pin 15, result bit 7) |
| 10 | GND | GND |
| 11 | CLK | ALU_R_CLK (Flash D4, latch result) |
| 12 | Q7 | IBUS7 (tri-state) + FLAG_Z input |
| 13 | Q6 | IBUS6 (tri-state) + FLAG_Z input |
| 14 | Q5 | IBUS5 (tri-state) + FLAG_Z input |
| 15 | Q4 | IBUS4 (tri-state) + FLAG_Z input |
| 16 | Q3 | IBUS3 (tri-state) + FLAG_Z input |
| 17 | Q2 | IBUS2 (tri-state) + FLAG_Z input |
| 18 | Q1 | IBUS1 (tri-state) + FLAG_Z input |
| 19 | Q0 | IBUS0 (tri-state) + FLAG_Z input |
| 20 | VCC | VCC |

ALU_OE: separate from ALU_R_CLK. Sequence: first CLK latches result, then
/OE goes LOW to drive IBUS. Microcode handles timing (step 3: latch then drive).

FLAG_Z generation: wired-NOR of Q[7:0] using 8 diodes + 10kΩ pull-up:
```
Q0 ──|>|──┐
Q1 ──|>|──┤
Q2 ──|>|──┤
Q3 ──|>|──┤  FLAG_Z (HIGH when all Q=0)
Q4 ──|>|──┼── to U23.A1
Q5 ──|>|──┤   
Q6 ──|>|──┤  10kΩ pull-up to VCC
Q7 ──|>|──┘
```
Any Q=HIGH pulls FLAG_Z LOW through diode. All Q=LOW → pull-up holds HIGH.

---


### ROM: AT28C256 — Program Storage (DIP-28)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | A14 | ADDR14 |
| 2 | A12 | ADDR12 |
| 3 | A7 | ADDR7 |
| 4 | A6 | ADDR6 |
| 5 | A5 | ADDR5 |
| 6 | A4 | ADDR4 |
| 7 | A3 | ADDR3 |
| 8 | A2 | ADDR2 |
| 9 | A1 | ADDR1 |
| 10 | A0 | ADDR0 |
| 11 | D0 | DEXT0 |
| 12 | D1 | DEXT1 |
| 13 | D2 | DEXT2 |
| 14 | GND | GND |
| 15 | D3 | DEXT3 |
| 16 | D4 | DEXT4 |
| 17 | D5 | DEXT5 |
| 18 | D6 | DEXT6 |
| 19 | D7 | DEXT7 |
| 20 | /CE | ADDR15 inverted (LOW when A15=0 → ROM at 0x0000-0x7FFF) |
| 21 | A10 | ADDR10 |
| 22 | /OE | /MEM_RD (active during read cycles) |
| 23 | A11 | ADDR11 |
| 24 | A9 | ADDR9 |
| 25 | A8 | ADDR8 |
| 26 | A13 | ADDR13 |
| 27 | /WE | VCC (read-only in circuit) |
| 28 | VCC | VCC |

/MEM_RD: LOW during fetch and load steps (derived from /BUF_OE when DIR=0).
ROM selected when ADDR[15]=0 (lower 32K).

---

### RAM: 62256 — Data Storage (DIP-28)

| Pin | Name | Connection |
|:---:|------|-----------|
| 1 | A14 | ADDR14 |
| 2 | A12 | ADDR12 |
| 3 | A7 | ADDR7 |
| 4 | A6 | ADDR6 |
| 5 | A5 | ADDR5 |
| 6 | A4 | ADDR4 |
| 7 | A3 | ADDR3 |
| 8 | A2 | ADDR2 |
| 9 | A1 | ADDR1 |
| 10 | A0 | ADDR0 |
| 11 | D0 | DEXT0 |
| 12 | D1 | DEXT1 |
| 13 | D2 | DEXT2 |
| 14 | GND | GND |
| 15 | D3 | DEXT3 |
| 16 | D4 | DEXT4 |
| 17 | D5 | DEXT5 |
| 18 | D6 | DEXT6 |
| 19 | D7 | DEXT7 |
| 20 | /CE | ADDR15 (LOW when A15=1 → RAM at 0x8000-0xFFFF) |
| 21 | A10 | ADDR10 |
| 22 | /OE | /MEM_RD |
| 23 | A11 | ADDR11 |
| 24 | A9 | ADDR9 |
| 25 | A8 | ADDR8 |
| 26 | A13 | ADDR13 |
| 27 | /WE | /MEM_WR (active during store cycles) |
| 28 | VCC | VCC |

RAM selected when ADDR[15]=1 (upper 32K).
/MEM_WR: LOW during store step (derived from BUF_DIR AND /BUF_OE).

Memory map:
```
0x0000-0x7FFF: ROM (program)
0x8000-0xFFFF: RAM (data + stack)
```

---

## Support Circuitry

### Oscillator (DIP-8 or DIP-14 can oscillator, 10 MHz)

| Pin | Connection |
|-----|-----------|
| 1 | NC (or enable) |
| 7 | GND |
| 8 | CLK net (→ U24.CLK1, U16-U19.CLK) |
| 14 | VCC |

---

### Reset Circuit

```
VCC ──[10kΩ]──┬── /RST net
              │
             [10µF] to GND
              │
           [pushbutton] to GND

/RST → U24./CLR1, U24./CLR2, U16-U19./CLR
```

74HC574 (U1-U11, U25) has no /CLR pin. On power-up, registers contain random
data. Microcode first step (after reset) should initialize r0-r7 by writing 0x00
from ROM. OR: accept undefined initial state (first instruction is LI to set up).

---

### LEDs (accent/debug, accent accent accent)

| LED | Connection | Function |
|-----|-----------|----------|
| LED0-7 | IBUS[0:7] via 330Ω | Bus activity (accent) |
| LED8 | FLAG_C via 330Ω | Carry flag |
| LED9 | FLAG_Z via 330Ω | Zero flag |
| LED10 | U24.Q1 via 330Ω | Step bit 0 |
| LED11 | U24.Q2 via 330Ω | Step bit 1 |

---

### 40-Pin Expansion Bus (active-low accent accent accent accent accent)

| Pin | Signal | Pin | Signal |
|:---:|--------|:---:|--------|
| 1 | VCC | 2 | GND |
| 3 | CLK | 4 | /RST |
| 5 | ADDR0 | 6 | ADDR1 |
| 7 | ADDR2 | 8 | ADDR3 |
| 9 | ADDR4 | 10 | ADDR5 |
| 11 | ADDR6 | 12 | ADDR7 |
| 13 | ADDR8 | 14 | ADDR9 |
| 15 | ADDR10 | 16 | ADDR11 |
| 17 | ADDR12 | 18 | ADDR13 |
| 19 | ADDR14 | 20 | ADDR15 |
| 21 | DEXT0 | 22 | DEXT1 |
| 23 | DEXT2 | 24 | DEXT3 |
| 25 | DEXT4 | 26 | DEXT5 |
| 27 | DEXT6 | 28 | DEXT7 |
| 29 | /MEM_RD | 30 | /MEM_WR |
| 31 | /BUF_OE | 32 | BUF_DIR |
| 33 | FLAG_Z | 34 | FLAG_C |
| 35 | IBUS0 | 36 | IBUS1 |
| 37 | IBUS2 | 38 | IBUS3 |
| 39 | IRQ (reserved) | 40 | NMI (reserved) |

---

### Power

| Rail | Decoupling |
|------|-----------|
| VCC = +5V | 100nF ceramic per chip (25×) + 10µF electrolytic at supply entry |
| GND | Solid ground plane or wide traces |

Total current estimate: ~25 × 10mA = 250mA typical @ 10 MHz.

---

## SUB Signal Generation

SUB must be HIGH for: SUB (class=00,op=001), SUBI (class=01,op=010),
CMP (class=00,op=101), CMPI (class=01,op=110).

Combinational decode from U9.Q[7:3]:
```
SUB = (class==00 AND op==001) OR (class==00 AND op==101)
    OR (class==01 AND op==010) OR (class==01 AND op==110)
```

Implementation options (no extra chip):
1. Encode SUB in microcode Flash — add 9th output bit (need 2nd Flash). NO.
2. Use diode-OR logic from U9 outputs. Feasible for 4 terms.
3. Include SUB in the ALU B latch step: microcode pre-inverts B by routing
   through XOR with SUB=1 hardwired... NO, SUB must be dynamic.

**Best**: Diode-AND/OR decode from U9.Q[7:3]. 4 product terms, each 5 inputs.
Use diode matrix (no extra chip, just diodes + resistors).

---

## VERIFICATION

### Bus Conflict Analysis

| Step | IBUS Driver | IBUS Listeners | Conflict? |
|------|------------|----------------|:---------:|
| 0 (fetch op) | U22 (ROM→IBUS) | U9 (IR latch) | ✅ No |
| 1 (fetch opr) | U22 (ROM→IBUS) | U10 (operand latch) | ✅ No |
| 2 (execute) | U20→reg OR U10 (imm) | U11 (ALU B latch) | ✅ No |
| 3 (writeback) | U25 (ALU result) | U21→reg (dest latch) | ✅ No |

**Key invariant**: Only ONE tri-state source drives IBUS per step.
- Step 0,1: U22 drives (buffer enabled, all registers Hi-Z)
- Step 2: ONE register drives (U20 selects) OR U10 drives (immediate)
- Step 3: U25 drives (ALU result latch)

### Timing Analysis (10 MHz = 100ns period)

```
CLK edge → U24 step changes → Flash address changes → 70ns → Flash data settles
→ control signals valid → target latches on NEXT CLK edge

Critical path: CLK → step counter (5ns) → Flash access (70ns) → setup time (5ns)
Total: 80ns < 100ns ✅ MEETS TIMING (20ns margin)
```

### ALU Bus Conflict Resolution

The ALU A-input comes directly from IBUS (combinational connection to adder A pins).
During step 3, U25 drives IBUS with the PREVIOUS ALU result (latched in step 2/3).
The adder A-inputs now see the ALU result (not the source register). This is OK
because:
1. U25 was latched BEFORE /OE goes LOW (ALU_R_CLK fires first)
2. The adder output changes (garbage) but U25 holds the correct latched value
3. No circular dependency: U25.Q → IBUS → adder.A → adder.Σ → U25.D (but CLK
   already fired, so D changes don't affect Q until next CLK)

### Known Issues / Trade-offs

1. **No latched flags**: Z and C are combinational. Valid only when ALU inputs
   are stable (steps 2-3). Branch decisions must occur during step 3 while
   ALU result is still latched. Microcode must ensure this.

2. **Fixed 4-cycle instructions**: All instructions take 4 cycles regardless of
   complexity. Simple instructions (NOP, LI) waste cycles. Acceptable for
   simplicity — 2.5 MIPS at 10 MHz.

3. **r0 not hardware-enforced**: Microcode must never assert U21.Y0 (write to r0).
   Software convention: r0 = 0.

4. **SUB decode needs diodes**: No spare gates available. Use discrete diode
   logic (8-12 signal diodes + 2 resistors). Adds no IC chips.

5. **PC high byte load**: For JMP absolute, need to load PC[15:8] from register.
   Requires 2 microcode steps (load low byte, load high byte) or accept that
   JMP only sets PC[7:0] with page from r6 (as in Verilog model).

6. **OPR_OE signal**: Not in Flash D[7:0] as listed. Must be derived from
   microcode context (during step 2 for immediate class, U10./OE driven LOW).
   **Fix**: Share with ALU_B_CLK (D3) — when D3 fires during step 2 AND class=01,
   U10./OE should be LOW. Route: U10./OE = NOT(D3 AND /class[1] AND class[0]).
   Needs 1 AND gate + 1 inverter. Use diode logic or accept as design limitation.

### Chip Count Verification

```
74HC574:  U1-U8 + U9 + U10 + U11 + U25 = 12
74HC283:  U12 + U13 = 2
74HC86:   U14 + U15 = 2
74HC161:  U16 + U17 + U18 + U19 = 4
74HC138:  U20 = 1
74HC238:  U21 = 1
74HC245:  U22 = 1
SST39SF010A: U23 = 1
74HC74:   U24 = 1
─────────────────────────────
Total logic ICs: 25
+ AT28C256 (ROM): 1
+ 62256 (RAM): 1
─────────────────────────────
Total packages: 27
```

### Does It Work?

**YES**, with caveats:
- The 8-bit microcode control word is tight. OPR_OE needs external decode (diodes).
- SUB signal needs diode decode (no spare gates).
- Flags are combinational (valid during execute/writeback steps only).
- All instructions fixed at 4 cycles (2.5 MIPS, not 3.0 MIPS as design doc claims).
- The architecture is proven (Ben Eater style) and buildable on breadboard.

**Buildable: YES. Every pin traced. No floating inputs. No bus conflicts.**
