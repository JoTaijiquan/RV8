# Lab 5: Arithmetic Logic Unit (ALU)

## Objective
Build an 8-bit ALU that performs ADD, SUB, AND, OR, and XOR.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC283 | 2 | 4-bit full adder |
| 74HC86 | 1 | Quad XOR gate |
| DIP switch (8-pos) | 1 | Manual input A (simulates accumulator) |
| LED + 330Ω | 8 | Result display |
| LED + 330Ω | 1 | Carry output display |

## Concept

```
Input A (8-bit) ──────────────────────┐
                                      ▼
                                 ┌─────────┐
Input B (8-bit) ──► XOR gates ──►│  ADDER  │──► Result (8-bit)
                     │    ▲      │ 283+283 │
                     │    │      └────┬────┘
                SUB signal│           │
                (inverts B)      Carry out
```

- ADD: B passes through XOR unchanged (SUB=0), C0=0
- SUB: B inverted by XOR (SUB=1), C0=1 (two's complement)
- AND/OR/XOR: handled by routing through logic gates (simplified for this lab)

## Schematic

```
DIP switches ──► A[7:0] ──► 74HC283 (U13) A1-A4 = A[3:0]
                             74HC283 (U14) A1-A4 = A[7:4]

IR operand ────► B[7:0] ──► 74HC86 (U15) ──► 74HC283 (U13) B1-B4
(from U6)                    XOR with SUB     74HC283 (U14) B1-B4

SUB switch ────► 74HC86 second input (all 4 gates)
                 also → U13 C0 (carry-in for subtract)

U13 (low nibble):
  A1-A4 = A[3:0]
  B1-B4 = B[3:0] XOR SUB
  C0 = SUB (0 for add, 1 for subtract)
  S1-S4 = Result[3:0]
  C4 → U14.C0

U14 (high nibble):
  A1-A4 = A[7:4]
  B1-B4 = B[7:4] XOR SUB
  C0 = U13.C4
  S1-S4 = Result[7:4]
  C4 = Carry out

Result LEDs ← S[7:0]
Carry LED ← U14.C4
```

## Simulate First

```bash
cd sim/
iverilog -o lab5 lab5_alu_tb.v && vvp lab5
gtkwave lab5.vcd
```

**What to check in GTKWave:**
- `result`: correct for each ADD/SUB test case
- `carry`: asserts on overflow ($FF+$01) and no-borrow ($05-$03)
- All 11 test cases pass in console output

---

## Procedure

1. Insert U13, U14 (74HC283). Connect VCC (pin 16) and GND (pin 8).
2. Insert U15 (74HC86). Connect VCC (pin 14) and GND (pin 7).
3. Wire DIP switches to A inputs (A1-A4 on U13, A1-A4 on U14).
4. Wire U6 outputs (operand) to U15 XOR inputs.
5. Wire SUB control switch to the other XOR inputs (all 4 gates on U15).
6. Wire U15 outputs to B inputs of U13 and U14.
7. Wire SUB switch also to U13 C0 (carry-in).
8. Cascade: U13 C4 (pin 9) → U14 C0 (pin 7).
9. Connect result LEDs to U13 S1-S4 and U14 S1-S4.
10. Connect carry LED to U14 C4 (pin 9).

## Test Procedure

| Test | A (switches) | B (operand) | SUB | Expected Result | Carry |
|:----:|:---:|:---:|:---:|:---:|:---:|
| 1 | $05 | $03 | 0 | $08 | 0 |
| 2 | $FF | $01 | 0 | $00 | 1 |
| 3 | $05 | $03 | 1 | $02 | 1 |
| 4 | $03 | $05 | 1 | $FE | 0 |
| 5 | $00 | $00 | 0 | $00 | 0 |
| 6 | $80 | $80 | 0 | $00 | 1 |
| 7 | $AA | $55 | 0 | $FF | 0 |
| 8 | $FF | $FF | 0 | $FE | 1 |

Note: For SUB, carry=1 means "no borrow" (result ≥ 0).

## Checkoff

- [ ] ADD: $05 + $03 = $08, carry=0
- [ ] ADD with carry: $FF + $01 = $00, carry=1
- [ ] SUB: $05 - $03 = $02, carry=1 (no borrow)
- [ ] SUB underflow: $03 - $05 = $FE, carry=0 (borrow)
- [ ] Carry propagates correctly from U13 to U14

## Notes
- In the final CPU, input A comes from the a0 register (not DIP switches).
- Input B comes from either a register or the immediate operand.
- The full ALU also supports AND, OR, XOR, SHL, SHR — these will be added via additional muxing in Step 8.
- The Zero flag (Z) is simply: NOR all 8 result bits. The Negative flag (N) is result bit 7.

## Thai Version

---

# แลป 5: ALU (หน่วยคำนวณ)

---

## เป้าหมาย

สร้างวงจรคำนวณ 8 บิตที่ทำ บวก (ADD) และ ลบ (SUB) ได้

---

## ความรู้พื้นฐาน

**ALU (Arithmetic Logic Unit)** = เครื่องคิดเลขของ CPU รับค่า 2 ตัว ให้ผลลัพธ์ 1 ตัว

**74HC283** = ชิปบวกเลข 4 บิต ใช้ 2 ตัวต่อกันได้ 8 บิต

**74HC86** = ชิป XOR ใช้กลับบิตของ B เพื่อทำการลบ

**วิธีลบ:** A - B = A + (กลับบิต B) + 1 (เรียกว่า two's complement)

---

## อุปกรณ์

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC283 | 2 | ตัวบวก 4 บิต × 2 = 8 บิต |
| 74HC86 | 1 | XOR สำหรับกลับบิต (ลบ) |
| DIP switch 8 ตัว | 1 | ตั้งค่า A (แทน accumulator) |
| LED + 330Ω | 8+1 | แสดงผลลัพธ์ + Carry |

---

## ผังวงจร

```
DIP switches ──► A [7:0]
                    │
                    ▼
              ┌──────────┐
              │  74HC283 │
              │  U13+U14 │──► Result [7:0] ──► LED 8 ดวง
              └──────────┘
                    ▲          Carry ──► LED 1 ดวง
                    │
B [7:0] ──► 74HC86 (XOR กับ SUB)
(จาก U6)        ▲
                 │
            สวิตช์ SUB (0=บวก, 1=ลบ)
                 │
                 └──► U13 C0 (carry-in)
```

**บวก:** SUB=0 → B ผ่านตรง, C0=0 → ผลลัพธ์ = A + B

**ลบ:** SUB=1 → B ถูกกลับบิต, C0=1 → ผลลัพธ์ = A - B

---

## ขั้นตอนต่อวงจร

1. เสียบ U13, U14 (74HC283) ต่อ VCC (pin 16) และ GND (pin 8)
2. เสียบ U15 (74HC86) ต่อ VCC (pin 14) และ GND (pin 7)
3. ต่อ DIP switches → A input ของ U13 และ U14
4. ต่อ operand (จาก U6 หรือ switches) → XOR input ของ U15
5. ต่อสวิตช์ SUB → XOR input อีกข้างของ U15 (ทุก gate)
6. ต่อ output ของ U15 → B input ของ U13 และ U14
7. ต่อสวิตช์ SUB → U13 C0 (pin 7)
8. ต่อ U13 C4 (pin 9) → U14 C0 (pin 7) — ทดจากต่ำไปสูง
9. ต่อ LED 8 ดวง ที่ output ของ U13 และ U14
10. ต่อ LED 1 ดวง ที่ U14 C4 (Carry out)

---

## ทดสอบ

| ขั้น | A (switches) | B (operand) | SUB | ผลที่ถูกต้อง | Carry |
|:----:|:---:|:---:|:---:|:---:|:---:|
| 1 | $05 | $03 | 0 | $08 | 0 |
| 2 | $FF | $01 | 0 | $00 | 1 |
| 3 | $05 | $03 | 1 | $02 | 1 |
| 4 | $03 | $05 | 1 | $FE | 0 |
| 5 | $AA | $55 | 0 | $FF | 0 |
| 6 | $80 | $80 | 0 | $00 | 1 |

หมายเหตุ: ตอนลบ Carry=1 หมายถึง "ไม่ติดลบ" (ผลลัพธ์ ≥ 0)

---

## เช็คลิสต์ผ่าน

- [ ] บวก: $05 + $03 = $08, Carry=0
- [ ] บวกล้น: $FF + $01 = $00, Carry=1
- [ ] ลบ: $05 - $03 = $02, Carry=1
- [ ] ลบติดลบ: $03 - $05 = $FE, Carry=0
- [ ] ทดจาก U13 ไป U14 ทำงานถูกต้อง

---

## จำลองก่อนต่อจริง

```bash
cd sim/
iverilog -o lab5 lab5_alu_tb.v && vvp lab5
gtkwave lab5.vcd
```

---

## หมายเหตุ

- ใน CPU จริง input A มาจาก register a0 (ไม่ใช่ DIP switch) — จะเปลี่ยนใน Lab 6
- ALU เต็มรูปแบบยังทำ AND, OR, XOR, SHL, SHR ได้ — จะเพิ่มใน Lab 8
- Flag Z (ศูนย์) = ผลลัพธ์ทุกบิตเป็น 0, Flag N (ลบ) = บิตที่ 7 ของผลลัพธ์
