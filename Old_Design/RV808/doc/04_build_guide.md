# RV808 — Step-by-Step Build Guide

Build the RV808 CPU across 8 labs on 3 breadboards. Each lab adds chips, test before moving on.

**Prerequisites**: Basic breadboard skills, know what VCC/GND/LED means.

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

**Chips**: Crystal oscillator module (3.5 MHz)

**Build**: Wire oscillator → CLK rail. Build /RST with 10K pull-up + 100nF + pushbutton.

**Test**: Scope shows 3.5 MHz. /RST clean on press/release.

**You now have**: Free-running clock + clean reset.

---

## Lab 2: ROM + PC (U1–U4 + ROM)

**Chips**: 74HC161 ×4 (4-Bit Synchronous Binary Counter) + AT28C256 (32K×8 EEPROM)

**Build**: Cascade four 161s via TC→ENT carry chain. Wire PC outputs directly to ROM address pins. ROM data output → LED (for testing).

**Test**: Pre-program ROM with $AA,$55 pattern. LEDs alternate as PC counts.

**You now have**: PC counts through ROM, data appears on output.

---

## Lab 3: Instruction Register (U5–U6)

**Chips**: 74HC574 ×2 (Octal D-Type Flip-Flop, 3-State)

**Build**: ROM D[7:0] → U5.D and U6.D. Gate CLK: U5 latches on F0, U6 on F1.

**Test**: Single-step. U5 shows opcode, U6 shows operand.

**You now have**: CPU fetches 2-byte instructions from ROM.

---

## Lab 4: Registers + Page Latch (U7–U10, U20)

**Chips**: 74HC574 ×5

**Build**: a0 input from ALU. t0/sp/pg from data bus. pg output → page latch (U20). Page latch → RAM A[14:8].

**Test**: Manually clock registers, verify data latches.

---

## Lab 5: ALU (U11–U13)

**Chips**: 74HC283 ×2 (4-Bit Binary Full Adder) + 74HC86 (Quad XOR)

**Build**: a0 → adder A. Operand → XOR → adder B. Result → a0 input.

**Test**: Set a0=5, operand=3. Verify sum=8 on LEDs.

---

## Lab 6: RAM + Address Decode (U21 + 62256)

**Chips**: 74HC138 (3-to-8 Decoder) + 62256 (32K×8 SRAM)

**Build**: Page latch → RAM A[14:8]. Operand/t0/sp → RAM A[7:0]. U21 decodes page for RAM vs I/O.

**Test**: Write byte, read back. Verify round-trip.

---

## Lab 7: Control Logic (U14–U18, U19)

**Chips**: 74HC138 + 74HC74 ×2 + 74HC08 + 74HC32 + 74HC245

**Build**: Full control: decode, flags, state, gates, bus buffer.

**Test**: Run program: `LI a0,$42; ADDI $08; HLT`. Verify a0=$4A.

---

## Lab 8: Expansion Bus (wiring)

**Build**: Wire 40-pin header. Connect /SLOT1-4, D[7:0], A[7:0], control.

**Test**: Plug I/O device, write to slot page, verify response.

**You now have**: Complete RV808 computer! 🎉

---

## Test Programs

### Test 1: Load + Add
```
$0000: A0 42    ; LI a0, $42
$0002: 20 08    ; ADDI $08
$0004: E1 00    ; HLT
; Result: a0 = $4A
```

### Test 2: Store + Load
```
$0000: A0 99    ; LI a0, $99
$0002: A3 00    ; PAGE $00
$0004: 44 10    ; SB pg:$10
$0006: A0 00    ; LI a0, $00
$0008: 40 10    ; LB pg:$10
$000A: E1 00    ; HLT
; Result: a0 = $99
```

### Test 3: Loop
```
$0000: A0 00    ; LI a0, $00
$0002: 84 00    ; INC
$0004: 22 05    ; CMPI $05
$0006: 61 FA    ; BNE -6
$0008: E1 00    ; HLT
; Result: a0 = $05
```

---

## Tips

- Wire VCC/GND to every chip FIRST
- Test each lab before moving on
- Colors: red=VCC, black=GND, yellow=address, blue=data, green=control
- ROM is directly wired to PC — simplest part of the build
- Single-step via Trainer board for debugging
- Keep wires short near clock and ROM

---

## Thai Version — คู่มือสร้าง RV808 CPU ทีละขั้น (พร้อมเลขขา)

---

# แลป 1: Clock + Reset

## เป้าหมาย
สร้างสัญญาณ Clock (จังหวะ) และ Reset (เริ่มใหม่)

## อุปกรณ์
| อุปกรณ์ | จำนวน |
|---------|:------:|
| Crystal Oscillator 3.5 MHz (4 ขา) | 1 |
| ปุ่มกด (RESET) | 1 |
| ตัวต้านทาน 10KΩ | 1 |
| ตัวเก็บประจุ 100nF | 2 |
| LED + 330Ω | 2 |

## วงจร Clock

| จุด | ต่อกับ |
|-----|--------|
| Crystal Oscillator VCC | +5V |
| Crystal Oscillator GND | GND |
| Crystal Oscillator OUT | **CLK rail** → ไปทุกชิป |
| 100nF | ระหว่าง VCC กับ GND (ใกล้ oscillator) |
| CLK rail | LED + 330Ω → GND |

## วงจร Reset

| จุด | ต่อกับ |
|-----|--------|
| +5V | 10K → จุด /RST |
| จุด /RST | ปุ่ม RESET → GND |
| จุด /RST | 100nF → GND |
| จุด /RST | **ออกไปขา /CLR ของทุกชิป** |
| จุด /RST | LED + 330Ω → GND |

## ทดสอบ
| ทำอะไร | ผลที่ถูกต้อง |
|--------|-------------|
| เปิดไฟ | LED CLK ติดค้าง (เร็วเกินเห็นกระพริบ) |
| กด RESET | LED RST ติด |
| ปล่อย RESET | LED RST ดับ |

---

# แลป 2: ROM + PC (5 ชิป)

## เป้าหมาย
สร้าง Program Counter ที่นับขึ้นทุก clock แล้วอ่านข้อมูลจาก ROM

## ชิป: 74HC161 ×4 — 4-Bit Synchronous Binary Counter

### Pinout ของ 74HC161 (DIP-16):
```
        ┌───╥───┐
  /CLR ─┤1  ╨ 16├─ VCC
   CLK ─┤2    15├─ TC (carry out)
    D0 ─┤3    14├─ QA (bit 0)
    D1 ─┤4    13├─ QB (bit 1)
    D2 ─┤5    12├─ QC (bit 2)
    D3 ─┤6    11├─ QD (bit 3)
   ENP ─┤7    10├─ ENT
   GND ─┤8     9├─ /LD
        └───────┘
```

### ขาที่เหมือนกันทุกตัว (U1–U4):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 2 | CLK | CLK rail |
| 1 | /CLR | /RST |
| 9 | /LD | +5V (ยังไม่โหลด — Lab 7 จะเปลี่ยน) |
| 7 | ENP | +5V |

### ขาที่ต่างกัน (carry chain):

| ชิป | ขา 10 (ENT) | ขา 15 (TC) | Q output → ROM |
|:---:|:-----------:|:----------:|:---------------|
| U1 | +5V | → U2 ขา 10 | QA→ROM A0, QB→A1, QC→A2, QD→A3 |
| U2 | U1 ขา 15 | → U3 ขา 10 | QA→ROM A4, QB→A5, QC→A6, QD→A7 |
| U3 | U2 ขา 15 | → U4 ขา 10 | QA→ROM A8, QB→A9, QC→A10, QD→A11 |
| U4 | U3 ขา 15 | (ไม่ต่อ) | QA→ROM A12, QB→A13, QC→A14 |

## ชิป: AT28C256 — 32K×8 EEPROM (DIP-28)

### Pinout:
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

### ตารางต่อสาย ROM:

| ขา ROM | ชื่อ | ต่อกับ |
|:------:|------|--------|
| 28 | VCC | +5V |
| 14 | GND | GND |
| 10 | A0 | U1 ขา 14 (QA) |
| 9 | A1 | U1 ขา 13 (QB) |
| 8 | A2 | U1 ขา 12 (QC) |
| 7 | A3 | U1 ขา 11 (QD) |
| 6 | A4 | U2 ขา 14 (QA) |
| 5 | A5 | U2 ขา 13 (QB) |
| 4 | A6 | U2 ขา 12 (QC) |
| 3 | A7 | U2 ขา 11 (QD) |
| 25 | A8 | U3 ขา 14 (QA) |
| 24 | A9 | U3 ขา 13 (QB) |
| 21 | A10 | U3 ขา 12 (QC) |
| 23 | A11 | U3 ขา 11 (QD) |
| 2 | A12 | U4 ขา 14 (QA) |
| 26 | A13 | U4 ขา 13 (QB) |
| 1 | A14 | U4 ขา 12 (QC) |
| 20 | /CE | GND (always selected) |
| 22 | /OE | GND (always read) |
| 27 | /WE | +5V (write disabled) |
| 11 | D0 | → LED 0 (ทดสอบ) |
| 12 | D1 | → LED 1 |
| 13 | D2 | → LED 2 |
| 15 | D3 | → LED 3 |
| 16 | D4 | → LED 4 |
| 17 | D5 | → LED 5 |
| 18 | D6 | → LED 6 |
| 19 | D7 | → LED 7 |

## ทดสอบ
| ทำอะไร | ผลที่ถูกต้อง |
|--------|-------------|
| โปรแกรม ROM ด้วย $AA,$55,$AA,$55... | LED สลับ 10101010 / 01010101 ทุก clock |
| กด RESET | LED แสดงค่าที่ address $0000 |

## ผลลัพธ์: PC นับขึ้น → ROM ส่งข้อมูลออกมาทีละไบต์

---

# แลป 3: Instruction Register (2 ชิป)

## เป้าหมาย
แยก opcode กับ operand ออกจากกัน — CPU รู้ว่า "ทำอะไร" (opcode) กับ "กับอะไร" (operand)

## ชิป: 74HC574 ×2 — Octal D-Type Flip-Flop (DIP-20)

### Pinout:
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

### U5 (IR Opcode):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND (output เปิดตลอด) |
| 11 | CLK | **ir0_clk** (= CLK AND state_F0) |
| 2-9 | D0-D7 | ROM D0-D7 (ขา 11-13, 15-19) |
| 12-19 | Q0-Q7 | → Decode (U14) + LED opcode |

### U6 (IR Operand):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND |
| 11 | CLK | **ir1_clk** (= CLK AND state_F1) |
| 2-9 | D0-D7 | ROM D0-D7 |
| 12-19 | Q0-Q7 | → RAM A[7:0] + ALU B input + LED operand |

### สร้าง ir0_clk และ ir1_clk:
ใช้ 74HC08 (AND gate) จาก Lab 7 — ตอนนี้ต่อชั่วคราวด้วยสวิตช์

## ทดสอบ
| ทำอะไร | ผลที่ถูกต้อง |
|--------|-------------|
| Single-step 1 ครั้ง | U5 LED แสดง opcode (byte แรกจาก ROM) |
| Single-step อีก 1 ครั้ง | U6 LED แสดง operand (byte ที่สองจาก ROM) |

## ผลลัพธ์: CPU แยก instruction เป็น opcode + operand ได้แล้ว

---

# แลป 4: Registers + Page Latch (5 ชิป)

## เป้าหมาย
สร้าง register 4 ตัว (a0, t0, sp, pg) + page latch สำหรับเข้าถึง RAM

## ชิป: 74HC574 ×5 (U7=a0, U8=t0, U9=sp, U10=pg, U20=page latch)

### U7 — a0 (Accumulator) ชิปสำคัญที่สุด:

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND (output เปิดตลอด) |
| 11 | CLK | **a0_clk** (จาก control logic) |
| 2-9 | D0-D7 | ALU result [7:0] |
| 12-19 | Q0-Q7 | → ALU input A + LED 8 ดวง |

### U8 — t0 (Temporary / Index):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND |
| 11 | CLK | **t0_clk** |
| 2-9 | D0-D7 | Data bus (จาก RAM หรือ operand) |
| 12-19 | Q0-Q7 | → RAM A[7:0] (pg:t0 mode) + ALU B |

### U9 — sp (Stack Pointer):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND |
| 11 | CLK | **sp_clk** |
| 2-9 | D0-D7 | Data bus (sp+1 หรือ sp-1 จาก ALU) |
| 12-19 | Q0-Q7 | → RAM A[7:0] (stack mode) |

### U10 — pg (Page Register):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND |
| 11 | CLK | **pg_clk** (= PAGE instruction execute) |
| 2-9 | D0-D7 | Operand (จาก U6) |
| 12-19 | Q0-Q7 | → U20 D input (page latch) |

### U20 — Page Latch (ส่ง high address ไป RAM):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | /OE | GND |
| 11 | CLK | **pg_clk** (เหมือน U10 — update พร้อมกัน) |
| 2-9 | D0-D7 | U10 Q0-Q7 (pg register output) |
| 12-18 | Q0-Q6 | → **RAM A8-A14** (7 bits = 128 pages) |
| 19 | Q7 | → Address decode (page ≥ $80 = external) |

## ทดสอบ
| ทำอะไร | ผลที่ถูกต้อง |
|--------|-------------|
| ตั้ง operand = $08, กด pg_clk | U10 LED = $08, U20 output = $08 |
| ตั้ง ALU result = $42, กด a0_clk | U7 LED = $42 |

## ผลลัพธ์: มี register 4 ตัว + page latch พร้อมส่ง address ไป RAM

---

# แลป 5: ALU — ADD/SUB/Logic (3 ชิป)

## เป้าหมาย
สร้างวงจรคำนวณ: บวก ลบ AND OR XOR

## ชิป: 74HC283 ×2 (U11, U12) — 4-Bit Binary Full Adder

### Pinout ของ 74HC283 (DIP-16):
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

### U11 (Adder bits 3:0):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 5 | A1 | a0 bit 0 (U7 ขา 12) |
| 3 | A2 | a0 bit 1 (U7 ขา 13) |
| 14 | A3 | a0 bit 2 (U7 ขา 14) |
| 12 | A4 | a0 bit 3 (U7 ขา 15) |
| 6 | B1 | U13 ขา 3 (XOR output bit 0) |
| 2 | B2 | U13 ขา 6 (XOR output bit 1) |
| 15 | B3 | U13 ขา 8 (XOR output bit 2) |
| 11 | B4 | U13 ขา 11 (XOR output bit 3) |
| 7 | C0 | carry_in (0=ADD, 1=SUB) |
| 4 | S1 | → a0 D0 (result bit 0) |
| 1 | S2 | → a0 D1 (result bit 1) |
| 13 | S3 | → a0 D2 (result bit 2) |
| 10 | S4 | → a0 D3 (result bit 3) |
| 9 | C4 | → **U12 ขา 7** (carry ทด) |

### U12 (Adder bits 7:4): เหมือน U11

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 5 | A1 | a0 bit 4 (U7 ขา 16) |
| 3 | A2 | a0 bit 5 (U7 ขา 17) |
| 14 | A3 | a0 bit 6 (U7 ขา 18) |
| 12 | A4 | a0 bit 7 (U7 ขา 19) |
| 6 | B1 | XOR output bit 4 |
| 2 | B2 | XOR output bit 5 |
| 15 | B3 | XOR output bit 6 |
| 11 | B4 | XOR output bit 7 |
| 7 | C0 | **U11 ขา 9** (carry จาก low nibble) |
| 4 | S1 | → a0 D4 (result bit 4) |
| 1 | S2 | → a0 D5 |
| 13 | S3 | → a0 D6 |
| 10 | S4 | → a0 D7 |
| 9 | C4 | → **flag_c** (carry out) |

## ชิป: 74HC86 (U13) — Quad 2-Input XOR Gate

### Pinout (DIP-14):
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

### U13 ต่อสาย:

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 1 | 1A | Operand bit 0 (U6 ขา 12) |
| 2 | 1B | **SUB signal** (0=ADD, 1=SUB — กลับบิต) |
| 3 | 1Y | → U11 ขา 6 (B1) |
| 4 | 2A | Operand bit 1 (U6 ขา 13) |
| 5 | 2B | SUB signal |
| 6 | 2Y | → U11 ขา 2 (B2) |
| 9 | 3A | Operand bit 2 (U6 ขา 14) |
| 10 | 3B | SUB signal |
| 8 | 3Y | → U11 ขา 15 (B3) |
| 12 | 4A | Operand bit 3 (U6 ขา 15) |
| 13 | 4B | SUB signal |
| 11 | 4Y | → U11 ขา 11 (B4) |

**หมายเหตุ**: XOR 4 gate ใน U13 ครอบคลุมแค่ bit 0-3 ต้องใช้ XOR เพิ่มสำหรับ bit 4-7 (ใช้ gate ว่างจากชิปอื่น หรือเพิ่ม 74HC86 อีก 1 ตัว)

## ทดสอบ
| ทำอะไร | ผลที่ถูกต้อง |
|--------|-------------|
| a0=$05, operand=$03, SUB=0 | Result LED = $08 (5+3) |
| a0=$05, operand=$03, SUB=1 | Result LED = $02 (5-3) |

## ผลลัพธ์: ALU บวก/ลบ ทำงานได้!

---

# แลป 6: RAM + Address Decode (3 ชิป)

## เป้าหมาย
ต่อ RAM เพื่อเก็บข้อมูล — CPU เขียน/อ่านผ่าน page:offset

## ชิป: 62256 — 32K×8 Static RAM (DIP-28)

### Pinout (เหมือน AT28C256):
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

### ตารางต่อสาย RAM:

| ขา RAM | ชื่อ | ต่อกับ |
|:------:|------|--------|
| 28 | VCC | +5V |
| 14 | GND | GND |
| 10 | A0 | RAM address mux bit 0 (จาก operand/t0/sp) |
| 9 | A1 | RAM address mux bit 1 |
| 8 | A2 | RAM address mux bit 2 |
| 7 | A3 | RAM address mux bit 3 |
| 6 | A4 | RAM address mux bit 4 |
| 5 | A5 | RAM address mux bit 5 |
| 4 | A6 | RAM address mux bit 6 |
| 3 | A7 | RAM address mux bit 7 |
| 25 | A8 | U20 ขา 12 (page latch Q0) |
| 24 | A9 | U20 ขา 13 (page latch Q1) |
| 21 | A10 | U20 ขา 14 (page latch Q2) |
| 23 | A11 | U20 ขา 15 (page latch Q3) |
| 2 | A12 | U20 ขา 16 (page latch Q4) |
| 26 | A13 | U20 ขา 17 (page latch Q5) |
| 1 | A14 | U20 ขา 18 (page latch Q6) |
| 20 | /CE | จาก U21 (active เมื่อ page $00-$7F) |
| 22 | /OE | /RD (จาก control) |
| 27 | /WE | /WR (จาก control) |
| 11-13,15-19 | D0-D7 | ↔ internal data bus |

## ชิป: 74HC138 (U21) — Address Decode (DIP-16)

### Pinout:
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

### U21 ต่อสาย:

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 1 | A | U20 ขา 17 (page bit 5) |
| 2 | B | U20 ขา 18 (page bit 6) |
| 3 | C | U20 ขา 19 (page bit 7) |
| 6 | G1 | data_access signal (จาก control) |
| 4 | /G2A | GND |
| 5 | /G2B | GND |
| 15 | /Y0 | → RAM /CE (pages $00-$1F) |
| 14 | /Y1 | → RAM /CE (pages $20-$3F) — OR กับ /Y0 |
| 13 | /Y2 | → RAM /CE (pages $40-$5F) — OR กับ /Y0,/Y1 |
| 12 | /Y3 | → RAM /CE (pages $60-$7F) — OR กับ /Y0-/Y2 |
| 11 | /Y4 | → bus /SLOT1 (pages $80-$9F) |
| 10 | /Y5 | → bus /SLOT2 (pages $A0-$BF) |
| 9 | /Y6 | → bus /SLOT3 (pages $C0-$DF) |
| 7 | /Y7 | → bus /SLOT4 (pages $E0-$FF) |

**RAM /CE** = /Y0 AND /Y1 AND /Y2 AND /Y3 (ง่ายกว่า: ใช้ page bit 7 ตรงๆ — ถ้า bit7=0 → RAM)

## ทดสอบ
| ทำอะไร | ผลที่ถูกต้อง |
|--------|-------------|
| ตั้ง page=$00, offset=$10, เขียน $AA | RAM เก็บค่า |
| อ่านกลับจาก page=$00, offset=$10 | ได้ $AA |
| ตั้ง page=$80 | /SLOT1 active (LED ติด) |

## ผลลัพธ์: CPU อ่าน/เขียน RAM ผ่าน page:offset ได้!

---

# แลป 7: Control Logic (5 ชิป)

## เป้าหมาย
ต่อวงจรควบคุมทั้งหมด — CPU รันโปรแกรมเองได้!

## ชิป: 74HC138 (U14) — Instruction Unit Decode

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 1 | A | U5 ขา 17 (opcode bit 5) |
| 2 | B | U5 ขา 18 (opcode bit 6) |
| 3 | C | U5 ขา 19 (opcode bit 7) |
| 6 | G1 | execute_phase (state == EX) |
| 4 | /G2A | GND |
| 5 | /G2B | GND |
| 15-7 | /Y0-/Y7 | Unit select signals |

## ชิป: 74HC74 ×2 (U15, U16) — Flags + State

### U15 (Flags Z, C):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 2 | D1 | alu_zero (ALU result == 0) |
| 3 | CLK1 | flags_clk |
| 1 | /CLR1 | /RST |
| 4 | /PRE1 | +5V |
| 5 | Q1 | **Z flag** → branch logic |
| 12 | D2 | carry_out (U12 ขา 9) |
| 11 | CLK2 | flags_clk |
| 13 | /CLR2 | /RST |
| 10 | /PRE2 | +5V |
| 9 | Q2 | **C flag** → branch logic |

### U16 (N flag + state):

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 2 | D1 | ALU result bit 7 (sign) |
| 3 | CLK1 | flags_clk |
| 1 | /CLR1 | /RST |
| 4 | /PRE1 | +5V |
| 5 | Q1 | **N flag** → branch logic |
| 12 | D2 | state_next |
| 11 | CLK2 | CLK |
| 13 | /CLR2 | /RST |
| 10 | /PRE2 | +5V |
| 9 | Q2 | **state** (F0/F1 toggle) |

## ชิป: 74HC08 (U17) — Quad AND Gate

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 1 | 1A | CLK |
| 2 | 1B | state_F0 (U16 /Q) |
| 3 | 1Y | → **ir0_clk** (U5 ขา 11) |
| 4 | 2A | CLK |
| 5 | 2B | state_F1 (U16 Q) |
| 6 | 2Y | → **ir1_clk** (U6 ขา 11) |
| 9 | 3A | NOT(page bit 7) |
| 10 | 3B | data_access |
| 8 | 3Y | → **RAM /CE** |
| 12 | 4A | (spare) |
| 13 | 4B | (spare) |
| 11 | 4Y | (spare) |

## ชิป: 74HC32 (U18) — Quad OR Gate

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 14 | VCC | +5V |
| 7 | GND | GND |
| 1 | 1A | state_F0 |
| 2 | 1B | state_F1 |
| 3 | 1Y | → **pc_inc** (PC นับขึ้นตอน fetch) |
| 4 | 2A | state_M1 |
| 5 | 2B | state_M2 |
| 6 | 2Y | → **data_access** |
| 9-13 | gates 3-4 | (state logic / control combining) |

## ชิป: 74HC245 (U19) — Bus Buffer (DIP-20)

| ขา | ชื่อ | ต่อกับ |
|:--:|------|--------|
| 20 | VCC | +5V |
| 10 | GND | GND |
| 1 | DIR | read/write (HIGH=read, LOW=write) |
| 19 | /OE | io_active (เปิดเฉพาะ page $80+) |
| 2-9 | A1-A8 | internal data bus |
| 18-11 | B1-B8 | → external bus D[7:0] |

## ทดสอบ
โปรแกรม ROM ด้วย:
```
$0000: A0 42    ; LI a0, $42
$0002: 20 08    ; ADDI $08
$0004: E1 00    ; HLT
```
รัน → LED ที่ a0 ต้องแสดง $4A (= $42 + $08)

## ผลลัพธ์: **CPU รันโปรแกรมเองได้!** 🎉

---

# แลป 8: Expansion Bus (ต่อสาย)

## เป้าหมาย
ต่อ 40-pin bus header เพื่อเชื่อมต่ออุปกรณ์ภายนอก

## ต่อสาย Bus Header:

| ขา bus | สัญญาณ | มาจาก |
|:------:|--------|--------|
| 1-2 | GND | GND rail |
| 3-4 | VCC | +5V rail |
| 5 | CLK | CLK rail |
| 6 | /RST | /RST rail |
| 7 | /RD | control logic |
| 8 | /WR | control logic |
| 9 | /NMI | pull-up 10K → +5V |
| 10 | /IRQ | pull-up 10K → +5V |
| 11 | /SLOT1 | U21 ขา 11 (/Y4) |
| 12 | /SLOT2 | U21 ขา 10 (/Y5) |
| 13 | /SLOT3 | U21 ขา 9 (/Y6) |
| 14 | /SLOT4 | U21 ขา 7 (/Y7) |
| 15-18 | PG[4:7] | U20 ขา 16-19 |
| 21-28 | A[7:0] | RAM address mux output |
| 29-36 | D[7:0] | U19 B side (external data) |
| 37 | SYNC | instruction start pulse (จาก control) |
| 38-40 | N/A | ไม่ต่อ (สำรองไว้) |

## ทดสอบ
| ทำอะไร | ผลที่ถูกต้อง |
|--------|-------------|
| ต่อ LED ที่ /SLOT1 | PAGE $80 → LED ติด |
| ต่อ LED board ที่ D[7:0] | เขียนไป slot → LED แสดงค่า |

## ผลลัพธ์: **RV808 สมบูรณ์! พร้อมต่ออุปกรณ์ภายนอก!** 🎉

---

# สรุปชิปทั้งหมด (23 ตัว)

| U# | ชิป | ชื่อ TTL เต็ม | หน้าที่ |
|:--:|------|--------------|---------|
| U1 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 3:0 |
| U2 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 7:4 |
| U3 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 11:8 |
| U4 | 74HC161 | 4-Bit Synchronous Binary Counter | PC bit 15:12 |
| U5 | 74HC574 | Octal D-Type Flip-Flop (3-State) | IR opcode |
| U6 | 74HC574 | Octal D-Type Flip-Flop (3-State) | IR operand |
| U7 | 74HC574 | Octal D-Type Flip-Flop (3-State) | a0 (accumulator) |
| U8 | 74HC574 | Octal D-Type Flip-Flop (3-State) | t0 (index) |
| U9 | 74HC574 | Octal D-Type Flip-Flop (3-State) | sp (stack pointer) |
| U10 | 74HC574 | Octal D-Type Flip-Flop (3-State) | pg (page register) |
| U11 | 74HC283 | 4-Bit Binary Full Adder | ALU adder low |
| U12 | 74HC283 | 4-Bit Binary Full Adder | ALU adder high |
| U13 | 74HC86 | Quad 2-Input XOR Gate | SUB invert + XOR op |
| U14 | 74HC138 | 3-to-8 Line Decoder | Instruction decode |
| U15 | 74HC74 | Dual D-Type Flip-Flop | Flags: Z, C |
| U16 | 74HC74 | Dual D-Type Flip-Flop | N flag + state |
| U17 | 74HC08 | Quad 2-Input AND Gate | Control: clock gating |
| U18 | 74HC32 | Quad 2-Input OR Gate | Control: signal combine |
| U19 | 74HC245 | Octal Bus Transceiver | External bus buffer |
| U20 | 74HC574 | Octal D-Type Flip-Flop (3-State) | Page latch → RAM |
| U21 | 74HC138 | 3-to-8 Line Decoder | Address decode |
| — | AT28C256 | 32K×8 EEPROM | Program ROM |
| — | 62256 | 32K×8 Static RAM | Data RAM |

---

# เคล็ดลับสำหรับนักเรียน

1. **ต่อไฟก่อน** — VCC และ GND ทุกชิปก่อนต่อสายอื่น
2. **ตรวจทีละชิป** — ต่อเสร็จ 1 ชิป ทดสอบก่อนไปชิปถัดไป
3. **สายสี** — แดง=+5V, ดำ=GND, เหลือง=address, น้ำเงิน=data, เขียว=control
4. **สายสั้น** — ยิ่งสั้นยิ่งดี ลดสัญญาณรบกวน
5. **ขา 1 อยู่ตรงรอยบาก** — ดูรอยบากบนชิปเพื่อหาขา 1
6. **ROM ต่อตรงกับ PC** — ส่วนที่ง่ายที่สุด ไม่มี bus contention
7. **ใช้ Trainer board** สำหรับ single-step ดีบัก
8. **ทุก Lab มี simulation** — รันก่อนต่อจริงเสมอ!

---

# ไฟเลี้ยง — ต่อก่อนเป็นอันดับแรก!

| ชิป | ขา VCC | ขา GND |
|:---:|:------:|:------:|
| U1–U4 (74HC161) | 16 | 8 |
| U5–U10, U20 (74HC574) | 20 | 10 |
| U11–U12 (74HC283) | 16 | 8 |
| U13 (74HC86) | 14 | 7 |
| U14, U21 (74HC138) | 16 | 8 |
| U15–U16 (74HC74) | 14 | 7 |
| U17 (74HC08) | 14 | 7 |
| U18 (74HC32) | 14 | 7 |
| U19 (74HC245) | 20 | 10 |
| ROM (AT28C256) | 28 | 14 |
| RAM (62256) | 28 | 14 |
