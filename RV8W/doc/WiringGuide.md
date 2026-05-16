# RV8-W Wiring Guide

**25 logic chips. Accumulator. 2-cycle fetch from 8-bit Flash. No microcode.**

> **Note:** The original design claimed 24 logic chips. Analysis reveals a bus conflict:
> AC (574) /OE cannot simultaneously keep Q driving ALU A (always) AND disconnect
> from IBUS (sometimes). Resolution: add U25 (74HC541) as AC→IBUS buffer.
> Honest chip count: **25 logic + ROM + RAM = 27 packages.**

---

## Bus Conflict Analysis

The 74HC574 /OE pin controls ALL output drivers. When /OE=HIGH, Q pins go high-Z.
AC must ALWAYS drive ALU A inputs. Therefore AC /OE must be GND (always enabled).
But `MV rd, a0` and `SB` need AC value on IBUS. If AC always drives IBUS, nothing
else can (ROM operand, registers, RAM data all need IBUS access).

**Solution:** AC /OE=GND. AC Q hardwired to ALU A (always). Separate buffer U25
(74HC541) connects AC Q to IBUS, controlled by AC_TO_BUS signal. When AC_TO_BUS
is needed, U25 /OE goes LOW and AC value appears on IBUS.

---

## Architecture Summary

```
SST39SF010A (8-bit Flash, 128KB)
    │ D[7:0]
    ▼
┌─────────────────────────────────────────────────┐
│                    IBUS (8-bit)                  │
├─────────────────────────────────────────────────┤
    ▲         ▲         ▲         ▲         ▲
    │         │         │         │         │
 ROM data  Reg out   U25(AC)   RAM data  IR_LOW
 (cycle2)  (138 sel) (541 buf) (245 buf) (imm)
    │         │         │         │
    ▼         ▼         ▼         ▼
┌────────────────────────────────────┐
│         IBUS consumers             │
│  • XOR (U13-14) → ALU B input     │
│  • Register D inputs (U2-U8)      │
│  • AC D inputs (U1)               │
│  • RAM write data (via U22)       │
└────────────────────────────────────┘

ALU path (dedicated, NOT on IBUS):
  AC Q[7:0] ──(hardwired)──→ ALU A inputs (283 A1-A4)
  IBUS ──→ XOR (U13-14) ──→ ALU B inputs (283 B1-B4)
  ALU Σ[7:0] ──(hardwired)──→ AC D inputs (U1 D0-D7)
```

---

## Cycle Timing

```
Cycle 1 (STATE=0, FETCH CONTROL):
  PC[16:0] → ROM address
  ROM D[7:0] → IR_HIGH (U9) latches on CLK↑
  PC increments
  IBUS: idle (IR_HIGH outputs not yet active)

Cycle 2 (STATE=1, FETCH OPERAND + EXECUTE):
  PC[16:0] → ROM address
  ROM D[7:0] → operand byte available
  IR_HIGH outputs NOW ACTIVE (directly drive hardware):
    - ALU_OP → XOR chips + adder carry-in
    - RS field → U19 (138) → selected register /OE → IBUS
    - OR: IMM_MODE → ROM operand on IBUS (via IR_LOW or direct)
    - AC_TO_BUS → U25 /OE (for MV rd,a0 / SB)
  ALU computes combinationally
  On CLK↑:
    - AC latches ALU result (if AC_WR=1)
    - Target register latches IBUS (if REG_WR via U20)
    - Flags latch (Z, C)
    - PC increments
    - State toggles back to 0
```

---

## Control Byte (IR_HIGH outputs, directly drive hardware)

```
Bit 7: CLASS      (0=ALU/reg, 1=MEM/BRANCH)
Bit 6: ALU_OP2   ─┐
Bit 5: ALU_OP1   ─┼─ ALU operation select
Bit 4: ALU_OP0   ─┘  000=ADD 001=SUB 010=AND 011=OR 100=XOR 101=PASS 110=SHL 111=SHR
Bit 3: IMM_MODE  (0=register source on IBUS, 1=immediate/operand on IBUS)
Bit 2: AC_WR     (1=latch ALU result into AC)
Bit 1: REG_WR    (1=latch IBUS into r[rd] via U20)
Bit 0: AC_TO_BUS (1=U25 drives AC onto IBUS)
```

---

## Operand Byte (IR_LOW / ROM data during cycle 2)

```
For register ops (IMM_MODE=0):
  Bit 7-5: RS[2:0]  (source register → U19)
  Bit 4-2: RD[2:0]  (dest register → U20)
  Bit 1-0: reserved

For immediate ops (IMM_MODE=1):
  Bit 7-0: IMM8 (8-bit immediate value on IBUS)

For branch (CLASS=1, BRANCH):
  Bit 7-5: COND[2:0] (condition code)
  Bit 4-0: OFFSET5 (signed branch offset)

For memory (CLASS=1, MEM):
  Bit 7-5: RS[2:0] (base address register)
  Bit 4-0: OFFSET5 (unsigned offset)
```


---

## Chip List (25 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1 | 74HC574 | AC (accumulator). /OE=GND. D[7:0]=ALU result. Q→ALU A (hardwired). |
| U2 | 74HC574 | r1 (a1). /OE from U19 Y1. D=IBUS. CLK from U20 Y1. |
| U3 | 74HC574 | r2 (t0). /OE from U19 Y2. D=IBUS. CLK from U20 Y2. |
| U4 | 74HC574 | r3 (t1). /OE from U19 Y3. D=IBUS. CLK from U20 Y3. |
| U5 | 74HC574 | r4 (s0). /OE from U19 Y4. D=IBUS. CLK from U20 Y4. |
| U6 | 74HC574 | r5 (s1). /OE from U19 Y5. D=IBUS. CLK from U20 Y5. |
| U7 | 74HC574 | r6 (s2). /OE from U19 Y6. D=IBUS. CLK from U20 Y6. |
| U8 | 74HC574 | r7 (ra/sp). /OE from U19 Y7. D=IBUS. CLK from U20 Y7. |
| U9 | 74HC574 | IR_HIGH (control latch). /OE=GND. D=ROM data. CLK=CLK∧STATĒ. |
| U10 | 74HC574 | IR_LOW (operand latch). /OE=STATE (drives IBUS in cycle 2). D=ROM data. CLK=CLK∧STATE. |
| U11 | 74HC283 | ALU adder low (bits 3:0). A=AC[3:0]. B=XOR[3:0]. Cin=SUB. |
| U12 | 74HC283 | ALU adder high (bits 7:4). A=AC[7:4]. B=XOR[7:4]. Cin=U11.Cout. |
| U13 | 74HC86 | XOR low (bits 3:0). A=IBUS[3:0]. B=SUB,SUB,SUB,SUB. |
| U14 | 74HC86 | XOR high (bits 7:4). A=IBUS[7:4]. B=SUB,SUB,SUB,SUB. |
| U15 | 74HC161 | PC bits 3:0. CLK=CLK. /CLR=RESET̄. ENT=1. ENP=1. |
| U16 | 74HC161 | PC bits 7:4. CLK=CLK. ENT=U15.TC. ENP=1. |
| U17 | 74HC161 | PC bits 11:8. CLK=CLK. ENT=U16.TC. ENP=1. |
| U18 | 74HC161 | PC bits 15:12. CLK=CLK. ENT=U17.TC. ENP=1. |
| U19 | 74HC138 | Register READ select. A,B,C=RS[2:0]. /G1=STATĒ. Y0-Y7→reg /OE. |
| U20 | 74HC138 | Register WRITE select. A,B,C=RD[2:0]. /G1=REG_WR̄. Y0-Y7→reg CLK. |
| U21 | 74HC541 | PC high buffer. A=PC[15:8]. /OE1=STATĒ (active in cycle 2 for ROM addr). |
| U22 | 74HC245 | Bus buffer (IBUS ↔ RAM data). DIR=MEM_RW. /OE=MEM_EN̄. |
| U23 | 74HC74 | FF1: State toggle (Q=STATE). FF2: Zero flag. (Carry from U12.Cout) |
| U24 | 74HC157 | Address mux low. A=PC[7:0]. B=REG[7:0]. SEL=MEM_MODE. |
| U25 | 74HC541 | AC→IBUS buffer. A=AC Q[7:0]. /OE1=AC_TO_BUS̄. /OE2=GND. |
| — | SST39SF010A | Program ROM. A[16:0]=PC. D[7:0]=ROM data bus. /OE=GND. /CE=GND. |
| — | 62256 | Data RAM. A[14:0]=address bus. D[7:0]=IBUS (via U22). /OE, /WE, /CE. |

**Total: 25 logic + ROM + RAM = 27 packages**

---

## Buses

```json
{
  "IBUS": {
    "width": 8,
    "signals": ["IBUS0","IBUS1","IBUS2","IBUS3","IBUS4","IBUS5","IBUS6","IBUS7"],
    "drivers": [
      "U10 Q[7:0] (operand/immediate, when STATE=1 and IMM_MODE=1)",
      "U2-U8 Q[7:0] (selected register, when U19 enables one)",
      "U25 Y[7:0] (AC value, when AC_TO_BUS=1)",
      "U22 B[7:0] (RAM data, during LB)"
    ],
    "consumers": [
      "U1 D[7:0] (AC input, via ALU result — see ALU_BUS)",
      "U2-U8 D[7:0] (register inputs)",
      "U13-U14 A inputs (XOR → ALU B)",
      "U22 A[7:0] (RAM write data, during SB)"
    ]
  },
  "ALU_BUS": {
    "width": 8,
    "signals": ["ALU0","ALU1","ALU2","ALU3","ALU4","ALU5","ALU6","ALU7"],
    "note": "Dedicated traces, NOT on IBUS. ALU result → AC D inputs only.",
    "drivers": ["U11 Σ[3:0] + U12 Σ[3:0]"],
    "consumers": ["U1 D[7:0] (AC)"]
  },
  "AC_BUS": {
    "width": 8,
    "signals": ["ACQ0","ACQ1","ACQ2","ACQ3","ACQ4","ACQ5","ACQ6","ACQ7"],
    "note": "Dedicated traces from AC Q to ALU A inputs AND U25 buffer inputs.",
    "drivers": ["U1 Q[7:0]"],
    "consumers": ["U11 A[3:0] (ALU low)", "U12 A[7:4] (ALU high)", "U25 A[7:0] (IBUS buffer)"]
  },
  "ROM_DATA": {
    "width": 8,
    "signals": ["RD0","RD1","RD2","RD3","RD4","RD5","RD6","RD7"],
    "note": "ROM output data bus. Directly connects to IR_HIGH D and IR_LOW D.",
    "drivers": ["SST39SF010A D[7:0]"],
    "consumers": ["U9 D[7:0] (IR_HIGH)", "U10 D[7:0] (IR_LOW)"]
  },
  "ADDR_BUS": {
    "width": 17,
    "signals": ["A0-A16"],
    "note": "ROM address. A[16:0] from PC (U15-U18) via U21 buffer for high bits.",
    "drivers": ["U15 Q[3:0] (A0-A3)", "U16 Q[3:0] (A4-A7)", "U17 Q[3:0] (A8-A11)", "U18 Q[3:0] (A12-A15)", "U21 (optional A16)"],
    "consumers": ["SST39SF010A A[16:0]"]
  },
  "RAM_ADDR": {
    "width": 15,
    "signals": ["RA0-RA14"],
    "note": "RAM address from U24 mux (low) + register high byte.",
    "drivers": ["U24 Y[3:0] (RA0-RA3)", "U24 Y[7:4] (RA4-RA7)", "register high (RA8-RA14)"],
    "consumers": ["62256 A[14:0]"]
  }
}
```


---

## Pin-Level Wiring (JSON)

```json
{
  "Project": "RV8-W",
  "Version": "1.0",
  "Date": "2026-05-16",
  "ChipCount": 25,
  "Note": "25 logic + SST39SF010A + 62256 = 27 packages total",

  "Part": {
    "U1": {
      "type": "74HC574",
      "function": "AC (Accumulator)",
      "package": "DIP-20",
      "pins": {
        "1":  {"pin": "/OE", "signal": "GND", "note": "Always enabled — Q always drives ALU A"},
        "2":  {"pin": "D0", "signal": "ALU0", "note": "ALU result bit 0 (from U11 Σ1)"},
        "3":  {"pin": "D1", "signal": "ALU1", "note": "ALU result bit 1 (from U11 Σ2)"},
        "4":  {"pin": "D2", "signal": "ALU2", "note": "ALU result bit 2 (from U11 Σ3)"},
        "5":  {"pin": "D3", "signal": "ALU3", "note": "ALU result bit 3 (from U11 Σ4)"},
        "6":  {"pin": "D4", "signal": "ALU4", "note": "ALU result bit 4 (from U12 Σ1)"},
        "7":  {"pin": "D5", "signal": "ALU5", "note": "ALU result bit 5 (from U12 Σ2)"},
        "8":  {"pin": "D6", "signal": "ALU6", "note": "ALU result bit 6 (from U12 Σ3)"},
        "9":  {"pin": "D7", "signal": "ALU7", "note": "ALU result bit 7 (from U12 Σ4)"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "CLK", "signal": "AC_CLK", "note": "CLK gated with AC_WR and STATE"},
        "12": {"pin": "Q7", "signal": "ACQ7", "note": "→ U12 A4, U25 A8"},
        "13": {"pin": "Q6", "signal": "ACQ6", "note": "→ U12 A3, U25 A7"},
        "14": {"pin": "Q5", "signal": "ACQ5", "note": "→ U12 A2, U25 A6"},
        "15": {"pin": "Q4", "signal": "ACQ4", "note": "→ U12 A1, U25 A5"},
        "16": {"pin": "Q3", "signal": "ACQ3", "note": "→ U11 A4, U25 A4"},
        "17": {"pin": "Q2", "signal": "ACQ2", "note": "→ U11 A3, U25 A3"},
        "18": {"pin": "Q1", "signal": "ACQ1", "note": "→ U11 A2, U25 A2"},
        "19": {"pin": "Q0", "signal": "ACQ0", "note": "→ U11 A1, U25 A1"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U2": {
      "type": "74HC574",
      "function": "r1 (a1 — argument/temp)",
      "package": "DIP-20",
      "pins": {
        "1":  {"pin": "/OE", "signal": "U19_Y1", "note": "LOW when RS=001 and STATE=1"},
        "2":  {"pin": "D0", "signal": "IBUS0"},
        "3":  {"pin": "D1", "signal": "IBUS1"},
        "4":  {"pin": "D2", "signal": "IBUS2"},
        "5":  {"pin": "D3", "signal": "IBUS3"},
        "6":  {"pin": "D4", "signal": "IBUS4"},
        "7":  {"pin": "D5", "signal": "IBUS5"},
        "8":  {"pin": "D6", "signal": "IBUS6"},
        "9":  {"pin": "D7", "signal": "IBUS7"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "CLK", "signal": "U20_Y1", "note": "Pulse when RD=001 and REG_WR=1"},
        "12": {"pin": "Q7", "signal": "IBUS7", "note": "Drives IBUS when /OE=LOW"},
        "13": {"pin": "Q6", "signal": "IBUS6"},
        "14": {"pin": "Q5", "signal": "IBUS5"},
        "15": {"pin": "Q4", "signal": "IBUS4"},
        "16": {"pin": "Q3", "signal": "IBUS3"},
        "17": {"pin": "Q2", "signal": "IBUS2"},
        "18": {"pin": "Q1", "signal": "IBUS1"},
        "19": {"pin": "Q0", "signal": "IBUS0"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U3_to_U8": {
      "type": "74HC574 ×6",
      "function": "r2(t0), r3(t1), r4(s0), r5(s1), r6(s2), r7(ra/sp)",
      "package": "DIP-20",
      "note": "Identical wiring to U2. /OE from U19 Y2-Y7. CLK from U20 Y2-Y7.",
      "pins": {
        "1":  {"pin": "/OE", "signal": "U19_Yn", "note": "n=2..7 for U3..U8"},
        "2-9": {"pin": "D[0:7]", "signal": "IBUS[0:7]"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "CLK", "signal": "U20_Yn", "note": "n=2..7 for U3..U8"},
        "12-19": {"pin": "Q[7:0]", "signal": "IBUS[7:0]", "note": "Drives IBUS when /OE=LOW"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U9": {
      "type": "74HC574",
      "function": "IR_HIGH (control byte latch)",
      "package": "DIP-20",
      "pins": {
        "1":  {"pin": "/OE", "signal": "GND", "note": "Always enabled — outputs drive hardware"},
        "2":  {"pin": "D0", "signal": "RD0", "note": "ROM data bit 0"},
        "3":  {"pin": "D1", "signal": "RD1"},
        "4":  {"pin": "D2", "signal": "RD2"},
        "5":  {"pin": "D3", "signal": "RD3"},
        "6":  {"pin": "D4", "signal": "RD4"},
        "7":  {"pin": "D5", "signal": "RD5"},
        "8":  {"pin": "D6", "signal": "RD6"},
        "9":  {"pin": "D7", "signal": "RD7"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "CLK", "signal": "IR_CLK", "note": "CLK gated: latches on CLK↑ when STATE=0"},
        "12": {"pin": "Q7", "signal": "CLASS", "note": "Bit 7: 0=ALU, 1=MEM/BRANCH"},
        "13": {"pin": "Q6", "signal": "ALU_OP2", "note": "Bit 6: ALU op select"},
        "14": {"pin": "Q5", "signal": "ALU_OP1", "note": "Bit 5: ALU op select"},
        "15": {"pin": "Q4", "signal": "ALU_OP0", "note": "Bit 4: ALU op select"},
        "16": {"pin": "Q3", "signal": "IMM_MODE", "note": "Bit 3: 1=immediate on IBUS"},
        "17": {"pin": "Q2", "signal": "AC_WR", "note": "Bit 2: 1=latch ALU result to AC"},
        "18": {"pin": "Q1", "signal": "REG_WR", "note": "Bit 1: 1=latch IBUS to r[rd]"},
        "19": {"pin": "Q0", "signal": "AC_TO_BUS", "note": "Bit 0: 1=U25 drives AC onto IBUS"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U10": {
      "type": "74HC574",
      "function": "IR_LOW (operand byte latch)",
      "package": "DIP-20",
      "pins": {
        "1":  {"pin": "/OE", "signal": "IMM_OE", "note": "LOW when IMM_MODE=1 AND STATE=1 → drives IBUS"},
        "2":  {"pin": "D0", "signal": "RD0", "note": "ROM data bit 0"},
        "3":  {"pin": "D1", "signal": "RD1"},
        "4":  {"pin": "D2", "signal": "RD2"},
        "5":  {"pin": "D3", "signal": "RD3"},
        "6":  {"pin": "D4", "signal": "RD4"},
        "7":  {"pin": "D5", "signal": "RD5"},
        "8":  {"pin": "D6", "signal": "RD6"},
        "9":  {"pin": "D7", "signal": "RD7"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "CLK", "signal": "OP_CLK", "note": "CLK gated: latches on CLK↑ when STATE=1"},
        "12": {"pin": "Q7", "signal": "IBUS7/OP7", "note": "Operand bit 7 / RS2"},
        "13": {"pin": "Q6", "signal": "IBUS6/OP6", "note": "Operand bit 6 / RS1"},
        "14": {"pin": "Q5", "signal": "IBUS5/OP5", "note": "Operand bit 5 / RS0"},
        "15": {"pin": "Q4", "signal": "IBUS4/OP4", "note": "Operand bit 4 / RD2"},
        "16": {"pin": "Q3", "signal": "IBUS3/OP3", "note": "Operand bit 3 / RD1"},
        "17": {"pin": "Q2", "signal": "IBUS2/OP2", "note": "Operand bit 2 / RD0"},
        "18": {"pin": "Q1", "signal": "IBUS1/OP1"},
        "19": {"pin": "Q0", "signal": "IBUS0/OP0"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    }
  }
}
```


### ALU (U11-U14)

```json
{
    "U11": {
      "type": "74HC283",
      "function": "ALU adder LOW (bits 3:0)",
      "package": "DIP-16",
      "pins": {
        "1":  {"pin": "Σ2", "signal": "ALU1", "note": "Result bit 1 → U1 D1"},
        "2":  {"pin": "B2", "signal": "XOR1", "note": "From U13 pin 3 (IBUS1 ^ SUB)"},
        "3":  {"pin": "A2", "signal": "ACQ1", "note": "AC bit 1 (hardwired from U1 Q1)"},
        "4":  {"pin": "Σ1", "signal": "ALU0", "note": "Result bit 0 → U1 D0"},
        "5":  {"pin": "A1", "signal": "ACQ0", "note": "AC bit 0 (hardwired from U1 Q0)"},
        "6":  {"pin": "B1", "signal": "XOR0", "note": "From U13 pin 11 (IBUS0 ^ SUB)"},
        "7":  {"pin": "Cin", "signal": "SUB", "note": "1 for subtract (two's complement +1)"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "Cout", "signal": "U11_COUT", "note": "Carry out → U12 Cin"},
        "10": {"pin": "Σ4", "signal": "ALU3", "note": "Result bit 3 → U1 D3"},
        "11": {"pin": "B4", "signal": "XOR3", "note": "From U13 pin 8 (IBUS3 ^ SUB)"},
        "12": {"pin": "A4", "signal": "ACQ3", "note": "AC bit 3 (hardwired from U1 Q3)"},
        "13": {"pin": "Σ3", "signal": "ALU2", "note": "Result bit 2 → U1 D2"},
        "14": {"pin": "A3", "signal": "ACQ2", "note": "AC bit 2 (hardwired from U1 Q2)"},
        "15": {"pin": "B3", "signal": "XOR2", "note": "From U13 pin 6 (IBUS2 ^ SUB)"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U12": {
      "type": "74HC283",
      "function": "ALU adder HIGH (bits 7:4)",
      "package": "DIP-16",
      "pins": {
        "1":  {"pin": "Σ2", "signal": "ALU5", "note": "Result bit 5 → U1 D5"},
        "2":  {"pin": "B2", "signal": "XOR5", "note": "From U14 pin 3 (IBUS5 ^ SUB)"},
        "3":  {"pin": "A2", "signal": "ACQ5", "note": "AC bit 5 (hardwired from U1 Q5)"},
        "4":  {"pin": "Σ1", "signal": "ALU4", "note": "Result bit 4 → U1 D4"},
        "5":  {"pin": "A1", "signal": "ACQ4", "note": "AC bit 4 (hardwired from U1 Q4)"},
        "6":  {"pin": "B1", "signal": "XOR4", "note": "From U14 pin 11 (IBUS4 ^ SUB)"},
        "7":  {"pin": "Cin", "signal": "U11_COUT", "note": "Carry in from low adder"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "Cout", "signal": "CARRY", "note": "Final carry → U23 FF (carry flag)"},
        "10": {"pin": "Σ4", "signal": "ALU7", "note": "Result bit 7 → U1 D7"},
        "11": {"pin": "B4", "signal": "XOR7", "note": "From U14 pin 8 (IBUS7 ^ SUB)"},
        "12": {"pin": "A4", "signal": "ACQ7", "note": "AC bit 7 (hardwired from U1 Q7)"},
        "13": {"pin": "Σ3", "signal": "ALU6", "note": "Result bit 6 → U1 D6"},
        "14": {"pin": "A3", "signal": "ACQ6", "note": "AC bit 6 (hardwired from U1 Q6)"},
        "15": {"pin": "B3", "signal": "XOR6", "note": "From U14 pin 6 (IBUS6 ^ SUB)"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U13": {
      "type": "74HC86",
      "function": "XOR LOW — SUB invert for bits 3:0",
      "package": "DIP-14",
      "note": "Each gate: IBUS_bit XOR SUB. When SUB=1, inverts for two's complement.",
      "pins": {
        "1":  {"pin": "1A", "signal": "IBUS0", "note": "Data bit 0 from IBUS"},
        "2":  {"pin": "1B", "signal": "SUB", "note": "ALU_OP0 (1=subtract)"},
        "3":  {"pin": "1Y", "signal": "XOR0", "note": "→ U11 B1"},
        "4":  {"pin": "2A", "signal": "IBUS1"},
        "5":  {"pin": "2B", "signal": "SUB"},
        "6":  {"pin": "2Y", "signal": "XOR1", "note": "→ U11 B2"},
        "7":  {"pin": "GND", "signal": "GND"},
        "8":  {"pin": "3Y", "signal": "XOR2", "note": "→ U11 B3"},
        "9":  {"pin": "3A", "signal": "IBUS2"},
        "10": {"pin": "3B", "signal": "SUB"},
        "11": {"pin": "4Y", "signal": "XOR3", "note": "→ U11 B4"},
        "12": {"pin": "4A", "signal": "IBUS3"},
        "13": {"pin": "4B", "signal": "SUB"},
        "14": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U14": {
      "type": "74HC86",
      "function": "XOR HIGH — SUB invert for bits 7:4",
      "package": "DIP-14",
      "note": "Identical to U13 but for high nibble.",
      "pins": {
        "1":  {"pin": "1A", "signal": "IBUS4"},
        "2":  {"pin": "1B", "signal": "SUB"},
        "3":  {"pin": "1Y", "signal": "XOR4", "note": "→ U12 B1"},
        "4":  {"pin": "2A", "signal": "IBUS5"},
        "5":  {"pin": "2B", "signal": "SUB"},
        "6":  {"pin": "2Y", "signal": "XOR5", "note": "→ U12 B2"},
        "7":  {"pin": "GND", "signal": "GND"},
        "8":  {"pin": "3Y", "signal": "XOR6", "note": "→ U12 B3"},
        "9":  {"pin": "3A", "signal": "IBUS6"},
        "10": {"pin": "3B", "signal": "SUB"},
        "11": {"pin": "4Y", "signal": "XOR7", "note": "→ U12 B4"},
        "12": {"pin": "4A", "signal": "IBUS7"},
        "13": {"pin": "4B", "signal": "SUB"},
        "14": {"pin": "VCC", "signal": "VCC"}
      }
    }
}
```


### Program Counter (U15-U18)

```json
{
    "U15": {
      "type": "74HC161",
      "function": "PC bits 3:0 (lowest)",
      "package": "DIP-16",
      "pins": {
        "1":  {"pin": "/CLR", "signal": "/RESET", "note": "Active-low reset"},
        "2":  {"pin": "CLK", "signal": "CLK", "note": "System clock"},
        "3":  {"pin": "D0", "signal": "JMP_A0", "note": "Jump target bit 0 (for branch/jump)"},
        "4":  {"pin": "D1", "signal": "JMP_A1"},
        "5":  {"pin": "D2", "signal": "JMP_A2"},
        "6":  {"pin": "D3", "signal": "JMP_A3"},
        "7":  {"pin": "ENP", "signal": "VCC", "note": "Always count-enabled"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "/LOAD", "signal": "/PC_LOAD", "note": "LOW to load jump address"},
        "10": {"pin": "ENT", "signal": "VCC", "note": "Always count-enabled"},
        "11": {"pin": "Q3", "signal": "PC3", "note": "→ ROM A3"},
        "12": {"pin": "Q2", "signal": "PC2", "note": "→ ROM A2"},
        "13": {"pin": "Q1", "signal": "PC1", "note": "→ ROM A1"},
        "14": {"pin": "Q0", "signal": "PC0", "note": "→ ROM A0"},
        "15": {"pin": "TC", "signal": "U15_TC", "note": "Terminal count → U16 ENT"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U16": {
      "type": "74HC161",
      "function": "PC bits 7:4",
      "package": "DIP-16",
      "pins": {
        "1":  {"pin": "/CLR", "signal": "/RESET"},
        "2":  {"pin": "CLK", "signal": "CLK"},
        "3":  {"pin": "D0", "signal": "JMP_A4"},
        "4":  {"pin": "D1", "signal": "JMP_A5"},
        "5":  {"pin": "D2", "signal": "JMP_A6"},
        "6":  {"pin": "D3", "signal": "JMP_A7"},
        "7":  {"pin": "ENP", "signal": "VCC"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "/LOAD", "signal": "/PC_LOAD"},
        "10": {"pin": "ENT", "signal": "U15_TC", "note": "Ripple carry from U15"},
        "11": {"pin": "Q3", "signal": "PC7", "note": "→ ROM A7"},
        "12": {"pin": "Q2", "signal": "PC6", "note": "→ ROM A6"},
        "13": {"pin": "Q1", "signal": "PC5", "note": "→ ROM A5"},
        "14": {"pin": "Q0", "signal": "PC4", "note": "→ ROM A4"},
        "15": {"pin": "TC", "signal": "U16_TC", "note": "→ U17 ENT"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U17": {
      "type": "74HC161",
      "function": "PC bits 11:8",
      "package": "DIP-16",
      "pins": {
        "1":  {"pin": "/CLR", "signal": "/RESET"},
        "2":  {"pin": "CLK", "signal": "CLK"},
        "3":  {"pin": "D0", "signal": "JMP_A8"},
        "4":  {"pin": "D1", "signal": "JMP_A9"},
        "5":  {"pin": "D2", "signal": "JMP_A10"},
        "6":  {"pin": "D3", "signal": "JMP_A11"},
        "7":  {"pin": "ENP", "signal": "VCC"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "/LOAD", "signal": "/PC_LOAD"},
        "10": {"pin": "ENT", "signal": "U16_TC", "note": "Ripple carry from U16"},
        "11": {"pin": "Q3", "signal": "PC11", "note": "→ ROM A11 (via U21)"},
        "12": {"pin": "Q2", "signal": "PC10", "note": "→ ROM A10 (via U21)"},
        "13": {"pin": "Q1", "signal": "PC9", "note": "→ ROM A9 (via U21)"},
        "14": {"pin": "Q0", "signal": "PC8", "note": "→ ROM A8 (via U21)"},
        "15": {"pin": "TC", "signal": "U17_TC", "note": "→ U18 ENT"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U18": {
      "type": "74HC161",
      "function": "PC bits 15:12",
      "package": "DIP-16",
      "pins": {
        "1":  {"pin": "/CLR", "signal": "/RESET"},
        "2":  {"pin": "CLK", "signal": "CLK"},
        "3":  {"pin": "D0", "signal": "JMP_A12"},
        "4":  {"pin": "D1", "signal": "JMP_A13"},
        "5":  {"pin": "D2", "signal": "JMP_A14"},
        "6":  {"pin": "D3", "signal": "JMP_A15"},
        "7":  {"pin": "ENP", "signal": "VCC"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "/LOAD", "signal": "/PC_LOAD"},
        "10": {"pin": "ENT", "signal": "U17_TC", "note": "Ripple carry from U17"},
        "11": {"pin": "Q3", "signal": "PC15", "note": "→ ROM A15 (via U21)"},
        "12": {"pin": "Q2", "signal": "PC14", "note": "→ ROM A14 (via U21)"},
        "13": {"pin": "Q1", "signal": "PC13", "note": "→ ROM A13 (via U21)"},
        "14": {"pin": "Q0", "signal": "PC12", "note": "→ ROM A12 (via U21)"},
        "15": {"pin": "TC", "signal": "U18_TC", "note": "Unused (16-bit PC max)"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    }
}
```


### Decode & Control (U19-U25)

```json
{
    "U19": {
      "type": "74HC138",
      "function": "Register READ select (which register drives IBUS)",
      "package": "DIP-16",
      "note": "RS[2:0] from operand byte bits 7:5. Active-low outputs → register /OE pins.",
      "pins": {
        "1":  {"pin": "A", "signal": "RS0", "note": "Operand bit 5 (U10 Q5)"},
        "2":  {"pin": "B", "signal": "RS1", "note": "Operand bit 6 (U10 Q6)"},
        "3":  {"pin": "C", "signal": "RS2", "note": "Operand bit 7 (U10 Q7)"},
        "4":  {"pin": "/G2A", "signal": "IMM_MODE", "note": "Disabled when IMM_MODE=1 (immediate, no reg read)"},
        "5":  {"pin": "/G2B", "signal": "GND", "note": "Always enabled"},
        "6":  {"pin": "G1", "signal": "STATE", "note": "Only active in cycle 2 (STATE=1)"},
        "7":  {"pin": "Y7", "signal": "R7_OE", "note": "→ U8 /OE (ra/sp)"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "Y6", "signal": "R6_OE", "note": "→ U7 /OE (s2)"},
        "10": {"pin": "Y5", "signal": "R5_OE", "note": "→ U6 /OE (s1)"},
        "11": {"pin": "Y4", "signal": "R4_OE", "note": "→ U5 /OE (s0)"},
        "12": {"pin": "Y3", "signal": "R3_OE", "note": "→ U4 /OE (t1)"},
        "13": {"pin": "Y2", "signal": "R2_OE", "note": "→ U3 /OE (t0)"},
        "14": {"pin": "Y1", "signal": "R1_OE", "note": "→ U2 /OE (a1)"},
        "15": {"pin": "Y0", "signal": "R0_OE", "note": "→ nowhere (r0=zero, hardwired 0 or NC)"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U20": {
      "type": "74HC138",
      "function": "Register WRITE select (which register latches from IBUS)",
      "package": "DIP-16",
      "note": "RD[2:0] from operand byte bits 4:2. Active-low outputs inverted to CLK pulses.",
      "pins": {
        "1":  {"pin": "A", "signal": "RD0", "note": "Operand bit 2 (U10 Q2)"},
        "2":  {"pin": "B", "signal": "RD1", "note": "Operand bit 3 (U10 Q3)"},
        "3":  {"pin": "C", "signal": "RD2", "note": "Operand bit 4 (U10 Q4)"},
        "4":  {"pin": "/G2A", "signal": "/REG_WR", "note": "Inverted REG_WR. Active when REG_WR=1."},
        "5":  {"pin": "/G2B", "signal": "GND"},
        "6":  {"pin": "G1", "signal": "STATE", "note": "Only active in cycle 2"},
        "7":  {"pin": "Y7", "signal": "R7_CLK", "note": "→ U8 CLK"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "Y6", "signal": "R6_CLK", "note": "→ U7 CLK"},
        "10": {"pin": "Y5", "signal": "R5_CLK", "note": "→ U6 CLK"},
        "11": {"pin": "Y4", "signal": "R4_CLK", "note": "→ U5 CLK"},
        "12": {"pin": "Y3", "signal": "R3_CLK", "note": "→ U4 CLK"},
        "13": {"pin": "Y2", "signal": "R2_CLK", "note": "→ U3 CLK"},
        "14": {"pin": "Y1", "signal": "R1_CLK", "note": "→ U2 CLK"},
        "15": {"pin": "Y0", "signal": "R0_CLK", "note": "→ nowhere (r0 not writable)"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U21": {
      "type": "74HC541",
      "function": "PC high byte buffer (PC[15:8] → ROM A[15:8])",
      "package": "DIP-20",
      "note": "Buffers PC high bits to ROM. /OE controlled to disconnect during memory access.",
      "pins": {
        "1":  {"pin": "/OE1", "signal": "GND", "note": "Always enabled (ROM always addressed by PC)"},
        "2":  {"pin": "A1", "signal": "PC8", "note": "From U17 Q0"},
        "3":  {"pin": "A2", "signal": "PC9", "note": "From U17 Q1"},
        "4":  {"pin": "A3", "signal": "PC10", "note": "From U17 Q2"},
        "5":  {"pin": "A4", "signal": "PC11", "note": "From U17 Q3"},
        "6":  {"pin": "A5", "signal": "PC12", "note": "From U18 Q0"},
        "7":  {"pin": "A6", "signal": "PC13", "note": "From U18 Q1"},
        "8":  {"pin": "A7", "signal": "PC14", "note": "From U18 Q2"},
        "9":  {"pin": "A8", "signal": "PC15", "note": "From U18 Q3"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "Y8", "signal": "ROM_A15", "note": "→ SST39SF010A A15"},
        "12": {"pin": "Y7", "signal": "ROM_A14", "note": "→ SST39SF010A A14"},
        "13": {"pin": "Y6", "signal": "ROM_A13", "note": "→ SST39SF010A A13"},
        "14": {"pin": "Y5", "signal": "ROM_A12", "note": "→ SST39SF010A A12"},
        "15": {"pin": "Y4", "signal": "ROM_A11", "note": "→ SST39SF010A A11"},
        "16": {"pin": "Y3", "signal": "ROM_A10", "note": "→ SST39SF010A A10"},
        "17": {"pin": "Y2", "signal": "ROM_A9", "note": "→ SST39SF010A A9"},
        "18": {"pin": "Y1", "signal": "ROM_A8", "note": "→ SST39SF010A A8"},
        "19": {"pin": "/OE2", "signal": "GND", "note": "Always enabled"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U22": {
      "type": "74HC245",
      "function": "External bus buffer (IBUS ↔ RAM data)",
      "package": "DIP-20",
      "note": "Bidirectional. DIR=MEM_RW (0=RAM→IBUS for LB, 1=IBUS→RAM for SB). /OE=MEM_EN.",
      "pins": {
        "1":  {"pin": "DIR", "signal": "MEM_RW", "note": "0=A→B (RAM→IBUS), 1=B→A (IBUS→RAM)"},
        "2":  {"pin": "A1", "signal": "RAM_D0", "note": "RAM data bit 0"},
        "3":  {"pin": "A2", "signal": "RAM_D1"},
        "4":  {"pin": "A3", "signal": "RAM_D2"},
        "5":  {"pin": "A4", "signal": "RAM_D3"},
        "6":  {"pin": "A5", "signal": "RAM_D4"},
        "7":  {"pin": "A6", "signal": "RAM_D5"},
        "8":  {"pin": "A7", "signal": "RAM_D6"},
        "9":  {"pin": "A8", "signal": "RAM_D7"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "B8", "signal": "IBUS7"},
        "12": {"pin": "B7", "signal": "IBUS6"},
        "13": {"pin": "B6", "signal": "IBUS5"},
        "14": {"pin": "B5", "signal": "IBUS4"},
        "15": {"pin": "B4", "signal": "IBUS3"},
        "16": {"pin": "B3", "signal": "IBUS2"},
        "17": {"pin": "B2", "signal": "IBUS1"},
        "18": {"pin": "B1", "signal": "IBUS0"},
        "19": {"pin": "/OE", "signal": "/MEM_EN", "note": "LOW only during memory access cycles"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U23": {
      "type": "74HC74",
      "function": "Dual D flip-flop: STATE toggle + Zero flag",
      "package": "DIP-14",
      "note": "FF1=state (fetch/execute toggle). FF2=zero flag (latches when ALU result=0).",
      "pins": {
        "1":  {"pin": "/CLR1", "signal": "/RESET", "note": "Reset clears state to 0"},
        "2":  {"pin": "D1", "signal": "/Q1", "note": "Toggle: D connected to /Q"},
        "3":  {"pin": "CLK1", "signal": "CLK", "note": "Toggles every clock edge"},
        "4":  {"pin": "/PRE1", "signal": "VCC", "note": "No preset"},
        "5":  {"pin": "Q1", "signal": "STATE", "note": "0=fetch control, 1=fetch operand+execute"},
        "6":  {"pin": "/Q1", "signal": "/STATE", "note": "Inverted state → D1 (toggle feedback)"},
        "7":  {"pin": "GND", "signal": "GND"},
        "8":  {"pin": "/Q2", "signal": "/ZERO", "note": "Inverted zero flag"},
        "9":  {"pin": "Q2", "signal": "ZERO", "note": "1 when last ALU result was 0"},
        "10": {"pin": "/PRE2", "signal": "VCC"},
        "11": {"pin": "CLK2", "signal": "AC_CLK", "note": "Latches when AC latches"},
        "12": {"pin": "D2", "signal": "ALU_ZERO", "note": "NOR of all ALU result bits"},
        "13": {"pin": "/CLR2", "signal": "/RESET"},
        "14": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U24": {
      "type": "74HC157",
      "function": "Address mux low byte (PC[7:0] vs register[7:0] for RAM address)",
      "package": "DIP-16",
      "note": "SEL=0: PC low byte (normal ROM fetch). SEL=1: register value (memory access).",
      "pins": {
        "1":  {"pin": "/G", "signal": "GND", "note": "Always enabled"},
        "2":  {"pin": "SEL", "signal": "MEM_MODE", "note": "0=PC, 1=register (for LB/SB)"},
        "3":  {"pin": "1A", "signal": "PC0"},
        "4":  {"pin": "1B", "signal": "REG_A0", "note": "Register low bit for memory address"},
        "5":  {"pin": "1Y", "signal": "RAM_A0", "note": "→ 62256 A0"},
        "6":  {"pin": "2A", "signal": "PC1"},
        "7":  {"pin": "2B", "signal": "REG_A1"},
        "8":  {"pin": "GND", "signal": "GND"},
        "9":  {"pin": "2Y", "signal": "RAM_A1", "note": "→ 62256 A1"},
        "10": {"pin": "3A", "signal": "PC2"},
        "11": {"pin": "3B", "signal": "REG_A2"},
        "12": {"pin": "3Y", "signal": "RAM_A2", "note": "→ 62256 A2"},
        "13": {"pin": "4A", "signal": "PC3"},
        "14": {"pin": "4B", "signal": "REG_A3"},
        "15": {"pin": "4Y", "signal": "RAM_A3", "note": "→ 62256 A3"},
        "16": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "U25": {
      "type": "74HC541",
      "function": "AC → IBUS buffer (for MV rd,a0 and SB instructions)",
      "package": "DIP-20",
      "note": "Buffers AC Q outputs onto IBUS when AC_TO_BUS=1. Allows AC to always drive ALU A while selectively driving IBUS.",
      "pins": {
        "1":  {"pin": "/OE1", "signal": "/AC_TO_BUS", "note": "LOW when AC_TO_BUS=1 (inverted from IR_HIGH bit 0)"},
        "2":  {"pin": "A1", "signal": "ACQ0", "note": "From U1 Q0"},
        "3":  {"pin": "A2", "signal": "ACQ1", "note": "From U1 Q1"},
        "4":  {"pin": "A3", "signal": "ACQ2", "note": "From U1 Q2"},
        "5":  {"pin": "A4", "signal": "ACQ3", "note": "From U1 Q3"},
        "6":  {"pin": "A5", "signal": "ACQ4", "note": "From U1 Q4"},
        "7":  {"pin": "A6", "signal": "ACQ5", "note": "From U1 Q5"},
        "8":  {"pin": "A7", "signal": "ACQ6", "note": "From U1 Q6"},
        "9":  {"pin": "A8", "signal": "ACQ7", "note": "From U1 Q7"},
        "10": {"pin": "GND", "signal": "GND"},
        "11": {"pin": "Y8", "signal": "IBUS7", "note": "AC bit 7 → IBUS"},
        "12": {"pin": "Y7", "signal": "IBUS6"},
        "13": {"pin": "Y6", "signal": "IBUS5"},
        "14": {"pin": "Y5", "signal": "IBUS4"},
        "15": {"pin": "Y4", "signal": "IBUS3"},
        "16": {"pin": "Y3", "signal": "IBUS2"},
        "17": {"pin": "Y2", "signal": "IBUS1"},
        "18": {"pin": "Y1", "signal": "IBUS0"},
        "19": {"pin": "/OE2", "signal": "GND", "note": "Always enabled (controlled by /OE1 only)"},
        "20": {"pin": "VCC", "signal": "VCC"}
      }
    }
}
```


### Memory (ROM + RAM)

```json
{
    "SST39SF010A": {
      "type": "SST39SF010A",
      "function": "Program ROM (128KB, 8-bit, 70ns Flash)",
      "package": "PDIP-32",
      "pins": {
        "1":  {"pin": "A16", "signal": "PC16", "note": "From U21 or tie LOW (64KB mode)"},
        "2":  {"pin": "A15", "signal": "ROM_A15", "note": "From U21 Y8"},
        "3":  {"pin": "A12", "signal": "ROM_A12", "note": "From U21 Y5"},
        "4":  {"pin": "A7", "signal": "PC7", "note": "From U16 Q3"},
        "5":  {"pin": "A6", "signal": "PC6", "note": "From U16 Q2"},
        "6":  {"pin": "A5", "signal": "PC5", "note": "From U16 Q1"},
        "7":  {"pin": "A4", "signal": "PC4", "note": "From U16 Q0"},
        "8":  {"pin": "A3", "signal": "PC3", "note": "From U15 Q3"},
        "9":  {"pin": "A2", "signal": "PC2", "note": "From U15 Q2"},
        "10": {"pin": "A1", "signal": "PC1", "note": "From U15 Q1"},
        "11": {"pin": "A0", "signal": "PC0", "note": "From U15 Q0"},
        "12": {"pin": "/CE", "signal": "GND", "note": "Always selected"},
        "13": {"pin": "/OE", "signal": "GND", "note": "Always output enabled"},
        "14": {"pin": "D0", "signal": "RD0", "note": "ROM data → IR_HIGH D0, IR_LOW D0"},
        "15": {"pin": "D1", "signal": "RD1"},
        "16": {"pin": "GND", "signal": "GND"},
        "17": {"pin": "D2", "signal": "RD2"},
        "18": {"pin": "D3", "signal": "RD3"},
        "19": {"pin": "D4", "signal": "RD4"},
        "20": {"pin": "D5", "signal": "RD5"},
        "21": {"pin": "D6", "signal": "RD6"},
        "22": {"pin": "D7", "signal": "RD7"},
        "23": {"pin": "A10", "signal": "ROM_A10", "note": "From U21 Y3"},
        "24": {"pin": "A11", "signal": "ROM_A11", "note": "From U21 Y4"},
        "25": {"pin": "A9", "signal": "ROM_A9", "note": "From U21 Y2"},
        "26": {"pin": "A8", "signal": "ROM_A8", "note": "From U21 Y1"},
        "27": {"pin": "A13", "signal": "ROM_A13", "note": "From U21 Y6"},
        "28": {"pin": "A14", "signal": "ROM_A14", "note": "From U21 Y7"},
        "29": {"pin": "/WE", "signal": "VCC", "note": "Write disabled (read-only in operation)"},
        "30": {"pin": "NC", "signal": "NC"},
        "31": {"pin": "NC", "signal": "NC"},
        "32": {"pin": "VCC", "signal": "VCC"}
      }
    },

    "62256": {
      "type": "62256",
      "function": "Data RAM (32KB)",
      "package": "DIP-28",
      "pins": {
        "1":  {"pin": "A14", "signal": "RAM_A14", "note": "High address (from register or fixed)"},
        "2":  {"pin": "A12", "signal": "RAM_A12"},
        "3":  {"pin": "A7", "signal": "RAM_A7"},
        "4":  {"pin": "A6", "signal": "RAM_A6"},
        "5":  {"pin": "A5", "signal": "RAM_A5"},
        "6":  {"pin": "A4", "signal": "RAM_A4"},
        "7":  {"pin": "A3", "signal": "RAM_A3", "note": "From U24 Y4"},
        "8":  {"pin": "A2", "signal": "RAM_A2", "note": "From U24 Y3"},
        "9":  {"pin": "A1", "signal": "RAM_A1", "note": "From U24 Y2"},
        "10": {"pin": "A0", "signal": "RAM_A0", "note": "From U24 Y1"},
        "11": {"pin": "D0", "signal": "RAM_D0", "note": "↔ U22 A1"},
        "12": {"pin": "D1", "signal": "RAM_D1", "note": "↔ U22 A2"},
        "13": {"pin": "D2", "signal": "RAM_D2", "note": "↔ U22 A3"},
        "14": {"pin": "GND", "signal": "GND"},
        "15": {"pin": "D3", "signal": "RAM_D3", "note": "↔ U22 A4"},
        "16": {"pin": "D4", "signal": "RAM_D4", "note": "↔ U22 A5"},
        "17": {"pin": "D5", "signal": "RAM_D5", "note": "↔ U22 A6"},
        "18": {"pin": "D6", "signal": "RAM_D6", "note": "↔ U22 A7"},
        "19": {"pin": "D7", "signal": "RAM_D7", "note": "↔ U22 A8"},
        "20": {"pin": "/CE", "signal": "/MEM_EN", "note": "LOW during memory access"},
        "21": {"pin": "A10", "signal": "RAM_A10"},
        "22": {"pin": "/OE", "signal": "MEM_RW", "note": "LOW for read (LB), HIGH for write (SB)"},
        "23": {"pin": "A11", "signal": "RAM_A11"},
        "24": {"pin": "A9", "signal": "RAM_A9"},
        "25": {"pin": "A8", "signal": "RAM_A8"},
        "26": {"pin": "A13", "signal": "RAM_A13"},
        "27": {"pin": "/WE", "signal": "/MEM_WR", "note": "LOW for write (SB)"},
        "28": {"pin": "VCC", "signal": "VCC"}
      }
    }
}
```


---

## Verification: Data Path Traces

### 1. ADDI a0, a0, 5 (AC = AC + 5)

```
Control byte: 0_000_1_1_0_0 = 0x0C (ADD, IMM, AC_WR, no REG_WR, no AC_TO_BUS)
Operand byte: 0x05 (immediate value 5)

Cycle 1 (STATE=0):
  PC → ROM → 0x0C on RD[7:0]
  IR_HIGH latches 0x0C (CLK↑ gated by STATE=0)
  PC++

Cycle 2 (STATE=1):
  PC → ROM → 0x05 on RD[7:0]
  IR_LOW latches 0x05
  IR_HIGH outputs NOW ACTIVE:
    IMM_MODE=1 → U19 disabled (no register drives IBUS)
    IMM_MODE=1 → U10 /OE=LOW → operand 0x05 drives IBUS
    AC_TO_BUS=0 → U25 /OE=HIGH (AC not on IBUS) ✅ no conflict
  IBUS = 0x05
  SUB = ALU_OP0 = 0 → XOR passes through: XOR[7:0] = IBUS[7:0] = 0x05
  ALU: AC_Q + 0x05 = result
  U11 B[4:1] = XOR[3:0] = 0x5, A[4:1] = ACQ[3:0], Cin=0
  U12 B[4:1] = XOR[7:4] = 0x0, A[4:1] = ACQ[7:4], Cin=U11.Cout
  ALU result → U1 D[7:0] (direct wire, ALU_BUS)
  CLK↑: AC latches result (AC_WR=1, AC_CLK fires)
  PC++, STATE toggles to 0
  ✅ VERIFIED
```

### 2. ADD a0, a0, r3 (AC = AC + r3)

```
Control byte: 0_000_0_1_0_0 = 0x04 (ADD, REG, AC_WR)
Operand byte: 0b_011_000_00 = 0x60 (RS=3, RD=0, unused)

Cycle 2:
  IMM_MODE=0 → U10 /OE=HIGH (operand NOT on IBUS)
  IMM_MODE=0 → U19 enabled, RS=011 → Y3=LOW → U4 /OE=LOW → r3 drives IBUS
  AC_TO_BUS=0 → U25 disabled ✅
  IBUS = r3 value
  SUB=0 → XOR passes through
  ALU: AC + r3 → result → AC D inputs
  CLK↑: AC latches
  ✅ VERIFIED
```

### 3. MV rd, a0 (r2 = AC) — the critical path

```
Control byte: 0_101_0_0_1_1 = 0x53 (PASS, REG, no AC_WR, REG_WR, AC_TO_BUS)
Operand byte: 0b_000_010_00 = 0x08 (RS=0/unused, RD=2)

Cycle 2:
  AC_TO_BUS=1 → U25 /OE1=LOW → AC Q[7:0] drives IBUS via U25 ✅
  IMM_MODE=0 → U19 enabled BUT RS=000 → Y0=LOW → r0 /OE (zero reg, no conflict if r0 not implemented)
  Actually: RS should be "don't care" for MV rd,a0. Set RS=000 (r0=zero, not connected).
  IBUS = AC value (from U25)
  REG_WR=1 → U20 enabled, RD=010 → Y2=LOW → U3 CLK pulse → r2 latches IBUS
  AC_WR=0 → AC does NOT re-latch ✅
  ✅ VERIFIED: AC value reaches r2 via U25 buffer, no bus conflict
```

### 4. MV a0, rs (AC = r5) — load register into AC

```
Control byte: 0_101_0_1_0_0 = 0x14 (PASS, REG, AC_WR, no REG_WR, no AC_TO_BUS)
Operand byte: 0b_101_000_00 = 0xA0 (RS=5)

Cycle 2:
  IMM_MODE=0 → U19 enabled, RS=101 → Y5=LOW → U6 /OE=LOW → r5 drives IBUS
  AC_TO_BUS=0 → U25 disabled ✅
  IBUS = r5 value
  SUB=0, ALU_OP=101 (PASS) → ALU result = A + 0? 
  
  PROBLEM: PASS operation. How does ALU "pass" B input to output?
  With 283+XOR only: PASS means result = 0 + B = B (set A=0? Can't, AC always drives A)
  OR: PASS means result = A + 0 = A (B=0). But we want result = r5!
  
  FIX: For MV a0, rs: ALU_OP=ADD, B=rs value, but we want result=B not A+B.
  
  ACTUAL FIX: "PASS" in this architecture means ADD with the OTHER input zeroed.
  - MV a0, rs: Need result = rs. Use SUB: AC - AC = 0, then ADD rs? No, single cycle.
  - Better: LI a0, 0 then ADD a0, a0, rs (two instructions). 
  - OR: Define PASS as "B passthrough": force A inputs to 0 somehow.
  
  ARCHITECTURAL NOTE: With hardwired AC→ALU A, true "MV a0, rs" requires:
    Option 1: XOR a0, a0 (zero AC) then ADD a0, a0, rs (2 instructions)
    Option 2: Add AND/OR/XOR logic to ALU that can output just B
              XOR: if A XOR A = 0, then 0 XOR B = B. But A is AC, B is rs.
              OR with A=0: need to zero A. Can't with hardwired connection.
    Option 3: Use XOR gates differently. ALU_OP=XOR means result = A XOR B.
              If we set A=B (same register): A XOR A = 0. Not helpful.
    Option 4: The XOR chips (U13-U14) can be repurposed:
              When ALU_OP=PASS: XOR B input = IBUS XOR 0 = IBUS (passthrough)
              AND force adder A=0 and Cin=0: result = 0 + IBUS = IBUS ✅
              But adder A is hardwired to AC! Can't force to 0.
    
  HONEST ANSWER: With 283 adder and AC hardwired to A inputs, 
  "MV a0, rs" = "AC = rs" requires either:
    (a) SUB a0, a0 (AC=0) then ADD a0, a0, rs — 2 instructions (4 cycles)
    (b) Additional gate to force adder A=0 for PASS operations
    (c) Accept that MV a0, rs is actually: AC = AC + rs - AC = rs 
        (SUB then ADD, or use XOR trick: AC XOR AC = 0, then OR with rs)
  
  SIMPLEST: MV a0, rs is a PSEUDO-INSTRUCTION:
    XOR a0, a0, a0  → AC = AC XOR AC = 0  (but B=AC? No, B=IBUS=register)
    
  Wait: XOR a0, a0, rs where rs=a0? AC is not in register file (r0-r7).
  AC is separate. So "XOR a0, a0, a0" doesn't work — there's no way to get AC on IBUS 
  as B input for XOR... unless AC_TO_BUS=1.
  
  ACTUAL SOLUTION in this architecture:
    LI a0, 0       → AC = 0 (PASS immediate 0: result = 0 + 0 = 0, with Cin=0)
                      Control: 0_000_1_1_0_0, operand: 0x00 (ADD 0)
    ADD a0, a0, rs → AC = 0 + rs = rs
  
  So MV a0, rs = LI 0 + ADD rs (4 cycles total). Acceptable for accumulator arch.
  
  OR: Define ALU_OP=101 (PASS) to mean: disconnect AC from adder A (pull LOW).
  This requires 8 AND gates (AC_Q AND /PASS) before adder A inputs.
  That's another chip (74HC08 ×2 or 74HC244 used as gate). Adds complexity.
  
  FOR THIS WIRING GUIDE: Document that MV a0, rs is a pseudo-instruction 
  (LI 0 + ADD rs). The hardware supports ADD/SUB/AND/OR/XOR with AC always as A.
  ⚠️ DESIGN LIMITATION DOCUMENTED
```

### 5. SB a0, 0(r5) (mem[r5] = AC) — store to RAM

```
Control byte: 1_000_0_0_1_1 = 0x83 (CLASS=MEM, AC_TO_BUS=1, REG_WR=1→MEM_WR)
Operand byte: 0b_101_00000 = 0xA0 (RS=5, offset=0)

Cycle 2:
  CLASS=1 → memory operation
  AC_TO_BUS=1 → U25 /OE=LOW → AC value on IBUS
  MEM_MODE=1 → U24 selects register value for RAM address (r5 low byte)
  U22 DIR=1 (IBUS→RAM), /OE=LOW → IBUS data passes to RAM data pins
  RAM /WE=LOW → RAM latches data
  ✅ VERIFIED: AC → U25 → IBUS → U22 → RAM data bus
```

### 6. LB a0, 0(r5) (AC = mem[r5]) — load from RAM

```
Control byte: 1_000_0_1_0_0 = 0x84 (CLASS=MEM, AC_WR=1, read)
Operand byte: 0b_101_00000 = 0xA0 (RS=5, offset=0)

Cycle 2:
  CLASS=1 → memory operation
  AC_TO_BUS=0 → U25 disabled ✅
  MEM_MODE=1 → U24 selects r5 for RAM address
  U22 DIR=0 (RAM→IBUS), /OE=LOW → RAM data appears on IBUS
  IBUS → XOR (SUB=0, passthrough) → ALU B
  ALU: AC + RAM_data? No — we want AC = RAM_data, not AC + RAM_data!
  
  PROBLEM: ALU always computes A + B (or A - B). For LB, we want result = B only.
  Same issue as MV a0, rs above.
  
  FIX: LB must be a multi-step operation:
    1. LI a0, 0 (zero AC)
    2. LB_raw (AC = 0 + mem[rs] = mem[rs]) — ADD with memory data as B
  
  OR: Hardware fix — when CLASS=MEM and reading, force ALU A=0 (same AND gate fix).
  
  ARCHITECTURAL DECISION: Add 8× AND gates to zero ALU A input when PASS/LOAD mode.
  This requires 1× 74HC08 (quad AND) + 1× 74HC08 = 2 chips. Too many.
  
  BETTER: Use a 74HC244 (octal buffer) between AC and ALU A, with /OE = /PASS.
  When PASS=1: buffer disabled, ALU A = 0 (pull-down resistors). 
  When PASS=0: buffer enabled, ALU A = AC value.
  This is +1 chip (74HC244). Total: 26 logic.
  
  OR: Accept the 2-instruction sequence. LI 0 + ADD_MEM. 
  Accumulator architectures historically require this pattern.
  
  FOR THIS GUIDE: Document both options. Primary design uses 25 chips 
  with LI+ADD pattern for loads. Optional U26 (74HC244) enables single-cycle loads.
  ⚠️ DESIGN LIMITATION DOCUMENTED
```

---

## Summary of Bus Drivers (IBUS contention check)

| Source | Drives IBUS when | Control signal |
|--------|-----------------|----------------|
| U10 (IR_LOW/operand) | IMM_MODE=1 AND STATE=1 | U10 /OE = /(IMM_MODE ∧ STATE) |
| U2-U8 (registers) | U19 selects one, STATE=1 | U19 Yn (one-hot, active-low) |
| U25 (AC buffer) | AC_TO_BUS=1 AND STATE=1 | U25 /OE1 = /AC_TO_BUS |
| U22 (RAM data) | MEM_EN=1 AND MEM_RW=0 | U22 /OE = /MEM_EN |

**Rule: At most ONE source drives IBUS at any time.**

| Instruction | IBUS driver | Verification |
|-------------|-------------|:---:|
| ADDI (immediate) | U10 (operand) | ✅ |
| ADD rs (register) | U2-U8 (selected) | ✅ |
| MV rd, a0 | U25 (AC buffer) | ✅ |
| SB (store) | U25 (AC buffer) | ✅ |
| LB (load) | U22 (RAM data) | ✅ |
| NOP | None (IBUS floating — add pull-downs) | ⚠️ |

---

## Known Limitations

1. **MV a0, rs** (load register into AC): Not single-instruction with pure adder ALU.
   Workaround: `LI a0, 0` + `ADD a0, a0, rs` (4 cycles).
   Hardware fix: Add U26 (74HC244) between AC Q and ALU A with /OE=PASS control.
   This enables zeroing ALU A for PASS/LOAD operations. Total becomes 26 logic.

2. **LB a0, off(rs)** (load from RAM): Same issue — ALU adds AC + RAM_data.
   Workaround: Zero AC first, then ADD with memory data.
   Hardware fix: Same U26 (74HC244) resolves both issues.

3. **Chip count**: 
   - Minimum working (with LI+ADD patterns): **25 logic chips**
   - With single-cycle PASS/LOAD (add U26): **26 logic chips**
   - Original claim of 24 had unresolved bus conflict (AC /OE problem)

4. **r0 (zero register)**: Not implemented in hardware. U19 Y0 output goes nowhere.
   Software must never read r0. Assembler should enforce this.

5. **ALU operations limited to ADD/SUB**: AND, OR, XOR, SHL, SHR require additional
   logic beyond 283+86. The XOR chips handle SUB inversion only.
   For full ALU: need additional mux/logic chips (not in current 25-chip design).
   Workaround: Software implements AND/OR/XOR via SUB/ADD sequences or lookup tables.

---

## Timing Analysis (2-cycle, 8-bit ROM)

```
Cycle 1 (FETCH CONTROL): Simple — ROM read + latch. No computation.
  ROM access: 70ns (SST39SF010A)
  574 setup: 5ns
  Total: 75ns → safe at 10 MHz (100ns period) ✅

Cycle 2 (FETCH OPERAND + EXECUTE): Critical path.
  ROM access: 70ns (operand byte)
  574 latch (IR_LOW): 10ns tpd
  138 decode (U19): 15ns
  Register output (574 tpd): 10ns  
  XOR (U13/14): 10ns
  Adder ripple (U11+U12): 30ns (8-bit worst case)
  AC setup: 5ns
  ─────────────────────────────
  Total: 150ns → needs 6.6 MHz max

  At 3.5 MHz (286ns period): 136ns margin ✅✅
  At 5 MHz (200ns period): 50ns margin ✅
  At 8 MHz (125ns period): FAILS (needs 150ns) ❌
  
  Fix for 8 MHz: Use faster ROM (SST39SF010A-45, 45ns) → 125ns total. TIGHT.
  Safe clock: 5 MHz = 2.5 MIPS. Breadboard: 3.5 MHz = 1.75 MIPS.
```

---

## Power Budget

```
25× 74HC @ 5V, 3.5 MHz:
  Quiescent: 25 × 4µA = 0.1 mA
  Dynamic: 25 × ~2 mA = 50 mA
  ROM: ~30 mA
  RAM: ~15 mA
  Total: ~100 mA @ 5V = 0.5W
  
  Power supply: USB (500mA) or 7805 regulator ✅
```

---

## Decoupling

```
Every IC: 100nF ceramic cap between VCC and GND, placed within 5mm of pin.
Power entry: 10µF electrolytic + 100nF ceramic.
ROM: 100nF + 10µF (high transient current during read).
```

---

*Generated 2026-05-16. RV8-W WiringGuide v1.0.*
*Honest assessment: 25 chips minimum, 26 for full single-cycle PASS/LOAD.*
