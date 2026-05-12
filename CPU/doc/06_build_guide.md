# RV8 — Step-by-Step Build Guide

Build the RV8 CPU module-by-module across 12 labs. Each lab adds chips, and you test before moving on.

**Prerequisites**: You know 74HC logic, breadboards, and basic digital design.

---

## Build Order

```
Lab  1: Clock + Reset               (1 chip)    → square wave on scope
Lab  2: Program Counter              (4 chips)   → counts addresses
Lab  3: ROM + bus                    (3 chips)   → fetches bytes
Lab  4: Instruction Register         (2 chips)   → latches opcode+operand
Lab  5: ALU (ADD/SUB)               (3 chips)   → basic arithmetic
Lab  6: Registers                    (4 chips)   → accumulator feedback loop
Lab  7: Pointer + Address Mux        (4 chips)   → RAM access
Lab  8: Basic Control Logic          (6 chips)   → CPU runs simple programs
Lab  9: Full ALU                     (+3 chips)  → all logic/shift ops
Lab 10: Stack + Subroutines          (wiring)    → PUSH/POP/JAL/RET
Lab 11: Addressing Modes             (+1 chip)   → all memory modes + MOV
Lab 12: Interrupts + Skip            (+1 chip)   → NMI/IRQ/TRAP/RTI/SKIP
                                    ─────────
                                     27 chips total
```

---

## Instruction Coverage by Lab

| After Lab | Instructions Working | Cumulative |
|:---------:|:-------------------:|:----------:|
| 1–7 | Hardware only (no autonomous execution) | 0 |
| 8 | LI a0, ADDI, SUBI, CMPI, BEQ, BNE, BRA, LB/SB ptr, JMP, HLT | ~15 |
| 9 | +AND/OR/XOR/ADC/SBC, ANDI/ORI/XORI/TST, SHL/SHR/ROL/ROR/INC/DEC/NOT/SWAP | ~38 |
| 10 | +PUSH, POP, JAL, RET | ~42 |
| 11 | +LI sp/pl/ph/t0/pg, MOV, LB/SB zp/sp+imm/pg:imm, const gen, INC16/DEC16/ADD16 | ~58 |
| 12 | +SKIPZ/SKIPNZ/SKIPC/SKIPNC, EI/DI, TRAP, RTI, NMI, IRQ, NOP, CLC/SEC | **68** |

---

## Lab 1: Clock + Reset

**Chips**: 74HC157 (clock mux) + oscillator + RC debounce

**Build**: Wire 3.5 MHz oscillator and STEP button through 74HC157 mux. Add /RST with 10K pull-up + 100nF debounce.

**Test**: Scope shows 3.5 MHz in RUN, single pulse in STEP, clean /RST.

**You now have**: controllable clock + clean reset

---

## Lab 2: Program Counter (U1–U4)

**Chips**: 74HC161 ×4

**Build**: Cascade four 161s via TC→ENT carry chain. Connect CLK and /RST. Tie /LD and ENP HIGH.

**Test**: Single-step shows LEDs counting 0000→0001→... Carry propagates. Reset clears to 0000.

**You now have**: 16-bit address counter

---

## Lab 3: ROM + Bus Buffer (AT28C256, 74HC138, 74HC245)

**Chips**: AT28C256 + 74HC138 + 74HC245

**Build**: PC→ROM address, ROM data→245→data bus. Pre-program ROM with test pattern ($AA,$55,$01...).

**Test**: Single-step shows data bus cycling through ROM contents.

**You now have**: sequential byte fetch from ROM

---

## Lab 4: Instruction Register (U5–U6)

**Chips**: 74HC574 ×2 + 74HC74 (state toggle)

**Build**: Toggle FF alternates S0/S1. U5 latches opcode (S0), U6 latches operand (S1).

**Test**: ROM programmed with instruction pairs. U5/U6 capture correct bytes on alternating cycles.

**You now have**: 2-byte instruction fetch

---

## Lab 5: ALU — ADD/SUB (U13–U15)

**Chips**: 74HC283 ×2 + 74HC86

**Build**: Cascaded 4-bit adders. XOR gates invert B for SUB. DIP switches simulate input A.

**Test**: $05+$03=$08, $05-$03=$02, $FF+$01=$00 with carry.

**You now have**: 8-bit adder/subtractor

---

## Lab 6: Registers (U7–U10)

**Chips**: 74HC574 ×4 (a0, t0, sp, pg)

**Build**: a0 output→ALU input A (replace DIP switches). ALU result→a0 input. Manual clock buttons.

**Test**: Pulse a0_clk repeatedly with operand=5: a0 accumulates 5, 10, 15...

**You now have**: compute feedback loop (a0 = a0 OP B)

---

## Lab 7: Pointer + Address Mux (U11–U12, U16–U17)

**Chips**: 74HC161 ×2 (pointer) + 74HC157 ×2 (mux) + 62256 RAM

**Build**: Address mux selects PC or pointer. Pointer loads value, auto-increments. RAM on bus.

**Test**: Load pointer=$2000, write $42, read back $42. Switch between PC and pointer modes.

**You now have**: ROM + RAM access via pointer

---

## Lab 8: Basic Control Logic (U18–U23)

**Chips**: 74HC138 + 74HC74 ×2 + 74HC08 + 74HC32

**Build**: Opcode decode, flags (Z/C/N), state machine, control signal generation. Remove all manual switches. CPU runs autonomously.

**Test programs**:
- `LI a0, 5 / HLT` → a0=05
- `LI a0, 5 / ADDI 3 / HLT` → a0=08
- `LI a0, 0 / ADDI 1 / CMPI 10 / BNE -6 / HLT` → a0=0A
- `LI a0,$42 / SB (ptr) / LI a0,0 / LB (ptr) / HLT` → a0=$42

**You now have**: CPU executes basic programs (~15 instructions)

---

## Lab 9: Full ALU (+3 chips)

**Chips**: 74HC08 (AND) + 74HC32 (OR) + 74HC157 ×2 (result mux)

**Build**: Add AND/OR gates parallel to adder. Result mux selects Adder/AND/OR/XOR. Wire shift paths (no extra chips). Add carry-in control for ADC/SBC.

**Test**: ANDI, ORI, XORI, TST, SHL, SHR, ROL, ROR, INC, DEC, NOT, SWAP all produce correct results.

**You now have**: full arithmetic + logic + shift (~38 instructions)

---

## Lab 10: Stack + Subroutines (wiring only)

**Chips**: (no new chips — uses existing SP register + address mux + RAM)

**Build**: Add sp_inc/sp_dec to SP. Add stack address mode {$30,SP} and pre-decrement {$30,SP-1}. Add data_out mux for PUSH/JAL. Extend state machine for multi-cycle ops (S2/S3/S4).

**Test**: PUSH/POP round-trip, JAL/RET with nested calls.

**You now have**: subroutine calls + stack (~42 instructions)

---

## Lab 11: Addressing Modes (+1 chip)

**Chips**: 74HC157 (wr_sel mux, or use existing decode)

**Build**: Add wr_sel decode (LI to any register). Add address modes: zero-page {$00,imm}, sp+imm {$30,sp+imm}, page-relative {pg,imm}. Add constant generator on register read. Add MOV path through ALU.

**Test**: LI to all registers, MOV, zero-page/sp+imm/pg:imm load/store, constant generator.

**You now have**: all addressing modes + register ops (~58 instructions)

---

## Lab 12: Interrupts + Skip (+1 chip)

**Chips**: 74HC74 (NMI edge detect)

**Build**: NMI edge detector, IRQ level detect + IE gate. Vector fetch states (S5/S6). Skip flag (1-bit). TRAP push sequence. RTI pop+restore sequence. HLT with interrupt wake.

**Test**: SKIPZ/SKIPNZ/SKIPC/SKIPNC, EI/DI, IRQ wake from HLT, NMI, TRAP/RTI.

**You now have**: **complete RV8 CPU — all 68 instructions operational**

---

## Verification Milestones

| After Lab | You can verify |
|:---------:|---------------|
| 1 | Clock waveform on scope |
| 2 | Address bus counts up (LEDs) |
| 3 | Data bus shows ROM contents |
| 4 | IR holds opcode + operand pairs |
| 5 | ALU computes ADD/SUB correctly |
| 6 | Registers accumulate values |
| 7 | Pointer addresses RAM correctly |
| 8 | CPU runs programs autonomously |
| 9 | All ALU/logic/shift ops work |
| 10 | Subroutine calls and returns work |
| 11 | All memory modes + register routing work |
| 12 | Interrupts, skip, TRAP/RTI — full ISA verified |

---

## Test Programs

### Test 1: Load immediate (Lab 8)
```
$C000: 11 05    ; LI a0, 5
$C002: FF 00    ; HLT
```
Verify: a0 = 05, CPU halts.

### Test 2: Add (Lab 8)
```
$C000: 11 05    ; LI a0, 5
$C002: 16 03    ; ADDI 3
$C004: FF 00    ; HLT
```
Verify: a0 = 08.

### Test 3: Loop (Lab 8)
```
$C000: 11 00    ; LI a0, 0
$C002: 16 01    ; ADDI 1
$C004: 18 0A    ; CMPI 10
$C006: 31 FA    ; BNE -6 (back to $C002)
$C008: FF 00    ; HLT
```
Verify: a0 = 0A when halted.

### Test 4: Logic ops (Lab 9)
```
$C000: 11 F0    ; LI a0, $F0
$C002: 19 0F    ; ANDI $0F
$C004: FF 00    ; HLT
```
Verify: a0 = $00.

### Test 5: Subroutine (Lab 10)
```
$C000: 10 FF    ; LI sp, $FF
$C002: 12 20    ; LI pl, $20
$C004: 13 C0    ; LI ph, $C0
$C006: 3D 00    ; JAL
$C008: FF 00    ; HLT (return here)
; Subroutine at $C020:
$C020: 11 77    ; LI a0, $77
$C022: 3E 00    ; RET
```
Verify: a0 = $77.

### Test 6: Interrupt (Lab 12)
```
$C000: F2 00    ; EI
$C002: FF 00    ; HLT (wake on IRQ)
; IRQ vector at $FFFE→$C030
$C030: 11 EE    ; LI a0, $EE
$C032: FF 00    ; HLT
```
Verify: fire IRQ → a0 = $EE.

---

## Tips

- Add 8 LEDs on the data bus — you'll see every byte flow
- Add 8 LEDs on a0 output — watch the accumulator change
- Use single-step mode for debugging, free-run when it works
- If something's wrong, check the state machine first (is it advancing?)
- Keep wires short and color-coded: red=VCC, black=GND, yellow=address, blue=data, green=control
- Labs 1–8 get you a working CPU. Labs 9–12 complete the full ISA.
- Each lab has a simulation testbench — run it before wiring real chips!

---

## Thai Version — คู่มือสร้าง RV8 CPU ทีละขั้น (พร้อมเลขขา)

---

# แลป 1: Clock + Reset (1 ชิป)

## ชิป: 74HC157 (U25)

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 2 | 1A0 | Oscillator 3.5 MHz (output) |
| 3 | 1B0 | ปุ่ม STEP (ผ่าน 10K pull-up + 100nF debounce) |
| 1 | S | สวิตช์ RUN/STEP (LOW=RUN, HIGH=STEP) |
| 15 | /E | GND (เปิดตลอด) |
| 4 | 1Y0 | **CLK output** → ไปทุกชิปที่ต้องการ clock |

## วงจร Reset

| จุด | ต่อกับ |
|-----|--------|
| +5V | ตัวต้านทาน 10K → จุด /RST |
| จุด /RST | ปุ่ม RESET → GND |
| จุด /RST | 100nF → GND |
| จุด /RST | **ออกไปขา /CLR ของทุกชิป** |

## ผลลัพธ์: ได้สัญญาณ CLK และ /RST

---

# แลป 2: Program Counter (4 ชิป)

## ชิป: 74HC161 ×4 (U1, U2, U3, U4)

### ขาที่เหมือนกันทุกตัว (U1–U4):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 2 | CLK | CLK (จาก Lab 1) |
| 1 | /CLR | /RST (จาก Lab 1) |
| 9 | /LD | +5V (ยังไม่โหลด) |
| 7 | ENP | +5V |

### ขาที่ต่างกัน:

| ชิป | ขา 10 (ENT) | ขา 15 (TC) | Output (ขา 14,13,12,11) |
|:---:|:-----------:|:----------:|:-----------------------:|
| U1 | +5V | → U2 ขา 10 | A0, A1, A2, A3 |
| U2 | U1 ขา 15 | → U3 ขา 10 | A4, A5, A6, A7 |
| U3 | U2 ขา 15 | → U4 ขา 10 | A8, A9, A10, A11 |
| U4 | U3 ขา 15 | (ไม่ต่อ) | A12, A13, A14, A15 |

### ต่อ LED 8 ดวง:
- U1 ขา 14 (QA) → LED A0
- U1 ขา 13 (QB) → LED A1
- U1 ขา 12 (QC) → LED A2
- U1 ขา 11 (QD) → LED A3
- U2 ขา 14 (QA) → LED A4
- U2 ขา 13 (QB) → LED A5
- U2 ขา 12 (QC) → LED A6
- U2 ขา 11 (QD) → LED A7

## ผลลัพธ์: Address Bus A[15:0] นับขึ้นทุก clock

---

# แลป 3: ROM + Bus Buffer (3 ชิป)

## ชิป: AT28C256 (ROM)

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 28 | VCC | +5V |
| 14 | GND | GND |
| 10 | A0 | U1 ขา 14 (PC bit 0) |
| 9 | A1 | U1 ขา 13 |
| 8 | A2 | U1 ขา 12 |
| 7 | A3 | U1 ขา 11 |
| 6 | A4 | U2 ขา 14 |
| 5 | A5 | U2 ขา 13 |
| 4 | A6 | U2 ขา 12 |
| 3 | A7 | U2 ขา 11 |
| 25 | A8 | U3 ขา 14 |
| 24 | A9 | U3 ขา 13 |
| 21 | A10 | U3 ขา 12 |
| 23 | A11 | U3 ขา 11 |
| 2 | A12 | U4 ขา 14 |
| 26 | A13 | U4 ขา 13 |
| 1 | A14 | U4 ขา 12 |
| 20 | /CE | GND (เลือกตลอด สำหรับทดสอบ) |
| 22 | /OE | GND (อ่านตลอด) |
| 27 | /WE | +5V (ไม่เขียน) |
| 11–13, 15–19 | D0–D7 | → 74HC245 ฝั่ง A |

## ชิป: 74HC245 (Bus Buffer)

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | DIR | +5V (A→B) |
| 19 | /OE | GND (เปิดตลอด) |
| 2–9 | A1–A8 | ROM D0–D7 |
| 18–11 | B1–B8 | **Data Bus** → LED 8 ดวง |

## ชิป: 74HC138 (Address Decode) — ยังไม่ต่อใน Lab นี้ (ใช้ตอน Lab 8+)

## ผลลัพธ์: กด STEP แล้ว LED แสดงค่าจาก ROM ตามลำดับ

---

# แลป 4: Instruction Register (2 ชิป + toggle)

## ชิป: 74HC574 ×2 (U5 = opcode, U6 = operand)

### U5 (Opcode Register):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND (output เปิดตลอด) |
| 11 | CLK | ir0_clk (= CLK AND /state) |
| 2–9 | D1–D8 | Data Bus [0:7] |
| 19–12 | Q1–Q8 | **Opcode bits** → LED + ไป decode |

### U6 (Operand Register):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND |
| 11 | CLK | ir1_clk (= CLK AND state) |
| 2–9 | D1–D8 | Data Bus [0:7] |
| 19–12 | Q1–Q8 | **Operand bits** → ไป ALU input B |

### State Toggle (74HC74 — 1 flip-flop):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 3 | CLK | CLK |
| 1 | /CLR | /RST |
| 4 | /PRE | +5V |
| 2 | D | ขา 6 (/Q) ← ต่อกลับ! |
| 5 | Q | **state** (0=S0, 1=S1) |
| 6 | /Q | /state |

## ผลลัพธ์: U5 เก็บ opcode ทุก cycle คู่, U6 เก็บ operand ทุก cycle คี่

---

# แลป 5: ALU — ADD/SUB (3 ชิป)

## ชิป: 74HC283 ×2 (U13 = low nibble, U14 = high nibble)

### U13 (Adder bits 3:0):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 5 | A1 | a0 bit 0 (หรือ DIP switch) |
| 3 | A2 | a0 bit 1 |
| 14 | A3 | a0 bit 2 |
| 12 | A4 | a0 bit 3 |
| 6 | B1 | U15 output (B0 XOR SUB) |
| 2 | B2 | U15 output (B1 XOR SUB) |
| 15 | B3 | U15 output (B2 XOR SUB) |
| 11 | B4 | U15 output (B3 XOR SUB) |
| 7 | C0 | สวิตช์ SUB (0=ADD, 1=SUB) |
| 4 | S1 | Result bit 0 → LED |
| 1 | S2 | Result bit 1 → LED |
| 13 | S3 | Result bit 2 → LED |
| 10 | S4 | Result bit 3 → LED |
| 9 | C4 | → U14 ขา 7 (carry ทด) |

### U14 (Adder bits 7:4): เหมือน U13 แต่ใช้ bit 4–7, C0 มาจาก U13.C4

### U15 (74HC86 — XOR สำหรับ SUB):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 1 | 1A | Operand bit 0 (จาก U6) |
| 2 | 1B | สวิตช์ SUB |
| 3 | 1Y | → U13 ขา 6 (B1) |
| 4 | 2A | Operand bit 1 |
| 5 | 2B | สวิตช์ SUB |
| 6 | 2Y | → U13 ขา 2 (B2) |
| (ขา 9,10,11,12,13 สำหรับ bit 2–3 เหมือนกัน) |

## ผลลัพธ์: ตั้ง A และ B แล้วเห็นผลบวก/ลบบน LED

---

# แลป 6: Registers (4 ชิป)

## ชิป: 74HC574 ×4 (U7=a0, U8=t0, U9=sp, U10=pg)

### U7 (Accumulator a0) — ชิปสำคัญที่สุด:

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND (output เปิดตลอด) |
| 11 | CLK | a0_clk (ปุ่มกด หรือจาก control) |
| 2–9 | D1–D8 | ALU Result [0:7] |
| 19–12 | Q1–Q8 | → ALU input A + LED 8 ดวง |

### U8 (t0), U9 (sp), U10 (pg): เหมือน U7 แต่ D มาจาก Data Bus, CLK จากปุ่มแยก

**สำคัญ:** ถอด DIP switch ออกจาก ALU input A → ต่อ U7 Q output แทน (feedback loop!)

## ผลลัพธ์: กด a0_clk ซ้ำ → a0 สะสมค่า (5, 10, 15, 20...)

---

# แลป 7: Pointer + Address Mux (4 ชิป + RAM)

## ชิป: 74HC161 ×2 (U11=pl, U12=ph)

### U11 (Pointer Low):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 2 | CLK | CLK |
| 1 | /CLR | /RST |
| 9 | /LD | pl_load (ปุ่ม หรือ control) |
| 7 | ENP | ptr_inc |
| 10 | ENT | ptr_inc |
| 3–6 | D0–D3 | Data Bus [0:3] |
| 14,13,12,11 | QA–QD | → Address Mux input B [0:3] |
| 15 | TC | → U12 ขา 10 (ENT) |

### U12 (Pointer High): เหมือน U11, output → Mux B [8:11]

## ชิป: 74HC157 ×2 (U16=addr low, U17=addr high)

### U16 (Address Mux Low Byte):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 1 | S | addr_sel (0=PC, 1=Pointer) |
| 15 | /E | GND |
| 2 | 1A | PC bit 0 (U1 ขา 14) |
| 3 | 1B | Pointer bit 0 (U11 ขา 14) |
| 4 | 1Y | Address Bus A0 |
| (5,6,7 = ช่อง 2: A1) |
| (11,10,9 = ช่อง 3: A2) |
| (14,13,12 = ช่อง 4: A3) |

### U17 (Address Mux High Byte): เหมือน U16 สำหรับ bit 8–11

## ชิป: 62256 (RAM 32KB)

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 28 | VCC | +5V |
| 14 | GND | GND |
| 10–1, 25–23, 26, 2 | A0–A14 | Address Bus |
| 11–13, 15–19 | D0–D7 | Data Bus |
| 20 | /CE | GND (หรือ decode) |
| 22 | /OE | /RD (ปุ่ม หรือ control) |
| 27 | /WE | /WR (ปุ่ม หรือ control) |

## ผลลัพธ์: เขียน/อ่าน RAM ผ่าน pointer ได้

---

# แลป 8: Basic Control (6 ชิป)

## ชิป: 74HC138 (U18 — Unit Decode)

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 1 | A | U5 ขา 17 (opcode bit 5) |
| 2 | B | U5 ขา 16 (opcode bit 6) |
| 3 | C | U5 ขา 15 (opcode bit 7) |
| 6 | G1 | +5V |
| 4 | /G2A | GND |
| 5 | /G2B | GND |
| 15–7 | /Y0–/Y7 | Unit enable signals |

## ชิป: 74HC74 ×2 (U20=flags Z,C / U21=flag N + state)

### U20:

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 2 | D1 | Zero detect (NOR ของ result ทุกบิต) |
| 3 | CLK1 | flags_clk |
| 5 | Q1 | **Z flag** |
| 12 | D2 | U14 ขา 9 (Carry out) |
| 11 | CLK2 | flags_clk |
| 9 | Q2 | **C flag** |

### U21:

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 2 | D1 | ALU result bit 7 |
| 3 | CLK1 | flags_clk |
| 5 | Q1 | **N flag** |
| 12 | D2 | next_state logic |
| 11 | CLK2 | CLK |
| 9 | Q2 | state bit |

## ชิป: 74HC08 (U22 — AND gates)

| gate | inputs | output | หน้าที่ |
|:----:|--------|--------|---------|
| 1 | CLK + /state | ir0_clk | Clock U5 ตอน S0 |
| 2 | CLK + state | ir1_clk | Clock U6 ตอน S1 |
| 3 | execute + is_alu | a0_clk | เขียน a0 ตอน ALU |
| 4 | (สำรอง) | | |

## ชิป: 74HC32 (U23 — OR gates)

| gate | inputs | output | หน้าที่ |
|:----:|--------|--------|---------|
| 1 | S0 + S1 | pc_inc | เพิ่ม PC ตอน fetch |
| 2 | is_load + S2 | mem_rd | อ่าน memory |
| 3 | is_store + S2 | mem_wr | เขียน memory |
| 4 | (สำรอง) | | |

## สิ่งที่ต้องทำ:
- ถอดปุ่มกดและสวิตช์ทั้งหมดออก (ยกเว้น RUN/STEP/RESET)
- ต่อ control signals ไปยังทุกโมดูล:
  - a0_clk → U7 ขา 11
  - pc_inc → U1–U4 ขา 7+10
  - addr_sel → U16–U17 ขา 1
  - mem_rd → 74HC245 ขา 19
  - mem_wr → RAM ขา 27

## ผลลัพธ์: CPU รันโปรแกรมเองได้! (~15 คำสั่ง)

---

# แลป 9: Full ALU (+3 ชิป)

เพิ่ม: 74HC08 (AND op), 74HC32 (OR op), 74HC157 ×2 (result mux)

ต่อ A และ B เข้า AND/OR gate คู่ขนานกับ adder แล้วใช้ mux เลือกผลลัพธ์ตาม alu_op

Shift: ต่อสายใหม่ผ่าน mux (ไม่ต้องชิปเพิ่ม)

## ผลลัพธ์: AND/OR/XOR/SHL/SHR/ROL/ROR/INC/DEC/NOT/SWAP ทำงาน (~38 คำสั่ง)

---

# แลป 10: Stack + Subroutines (ต่อสายเพิ่ม)

ไม่ต้องชิปใหม่ — เพิ่ม:
- sp_inc / sp_dec logic ให้ U9 (SP)
- Address mode {$30, SP} และ {$30, SP-1}
- data_out mux สำหรับ PUSH (ส่งค่า register) และ JAL (ส่ง PC)
- State S2/S3/S4 สำหรับ multi-cycle ops

## ผลลัพธ์: PUSH/POP/JAL/RET ทำงาน (~42 คำสั่ง)

---

# แลป 11: Addressing Modes (+1 ชิป)

เพิ่ม: 74HC157 (wr_sel mux) หรือใช้ decode ที่มี

- wr_sel decode: เลือก register ที่จะเขียน (sp/a0/pl/ph/t0/pg)
- Address mode ใหม่: {$00, imm}, {$30, sp+imm}, {pg, imm}
- Constant generator: register x0 ให้ค่า 0/1/$FF/$80
- MOV path ผ่าน ALU

## ผลลัพธ์: LI ทุก register + MOV + ทุก addressing mode (~58 คำสั่ง)

---

# แลป 12: Interrupts + Skip (+1 ชิป)

เพิ่ม: 74HC74 (NMI edge detect)

- NMI: ขา D=VCC, CLK=NMI pin (falling edge), /CLR=int_ack
- IRQ: IRQ pin AND IE flag
- Vector fetch: state S5/S6 อ่าน vector address แล้วโหลด PC
- Skip flag: 1 บิต ตั้งโดย SKIPZ/NZ/C/NC
- TRAP: push PCH→PCL→flags→vector fetch
- RTI: pop flags→PCL→PCH→load PC

## ผลลัพธ์: **ครบ 68 คำสั่ง! CPU สมบูรณ์!** 🎉

---

# สรุปชิปทั้งหมด (27 ตัว)

| U# | ชิป | ชื่อ TTL เต็ม | หน้าที่ |
|:--:|------|--------------|---------|
| U1 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 3:0 |
| U2 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 7:4 |
| U3 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 11:8 |
| U4 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 15:12 |
| U5 | 74HC574 | Octal D-Type Flip-Flop (3-State) | IR opcode |
| U6 | 74HC574 | Octal D-Type Flip-Flop (3-State) | IR operand |
| U7 | 74HC574 | Octal D-Type Flip-Flop (3-State) | a0 (accumulator) |
| U8 | 74HC574 | Octal D-Type Flip-Flop (3-State) | t0 (temporary) |
| U9 | 74HC574 | Octal D-Type Flip-Flop (3-State) | sp (stack pointer) |
| U10 | 74HC574 | Octal D-Type Flip-Flop (3-State) | pg (page register) |
| U11 | 74HC161 | 4-Bit Synchronous Binary Counter | pl (pointer low) |
| U12 | 74HC161 | 4-Bit Synchronous Binary Counter | ph (pointer high) |
| U13 | 74HC283 | 4-Bit Binary Full Adder | ALU adder low nibble |
| U14 | 74HC283 | 4-Bit Binary Full Adder | ALU adder high nibble |
| U15 | 74HC86 | Quad 2-Input Exclusive-OR Gate | ALU XOR / SUB invert |
| U16 | 74HC157 | Quad 2-Input Multiplexer | Address mux low byte |
| U17 | 74HC157 | Quad 2-Input Multiplexer | Address mux high byte |
| U18 | 74HC138 | 3-to-8 Line Decoder/Demux | Instruction unit decode |
| U19 | 74HC245 | Octal Bus Transceiver (3-State) | Data bus buffer |
| U20 | 74HC74 | Dual D-Type Flip-Flop | Flags: Z, C |
| U21 | 74HC74 | Dual D-Type Flip-Flop | Flag N + state bit |
| U22 | 74HC08 | Quad 2-Input AND Gate | Control signal generation |
| U23 | 74HC32 | Quad 2-Input OR Gate | Control signal combining |
| U24 | 74HC74 | Dual D-Type Flip-Flop | NMI edge detect + state toggle |
| U25 | 74HC157 | Quad 2-Input Multiplexer | Clock mux (RUN/STEP) |
| — | AT28C256 | 32K×8 EEPROM | Program ROM |
| — | 62256 | 32K×8 Static RAM | Data RAM |

---

# เคล็ดลับ

- ต่อ LED 8 ดวงที่ Data Bus — จะเห็นทุกไบต์ที่ไหลผ่าน
- ต่อ LED 8 ดวงที่ a0 — ดูผลลัพธ์การคำนวณ
- ใช้ STEP mode ตอนดีบัก, RUN mode ตอนทำงานจริง
- ถ้ามีปัญหา ตรวจ state machine ก่อน (มันเดินไหม?)
- สายสี: แดง=VCC, ดำ=GND, เหลือง=address, น้ำเงิน=data, เขียว=control
- **Lab 1–8 ได้ CPU ทำงานเบื้องต้น, Lab 9–12 ครบ 68 คำสั่ง**
- ทุก Lab มี simulation — รันก่อนต่อจริงเสมอ!
