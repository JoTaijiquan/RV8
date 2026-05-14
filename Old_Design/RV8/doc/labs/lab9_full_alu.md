# Lab 9: Full ALU — Logic and Shift Operations

## Objective
Expand the ALU to support AND, OR, XOR, SHL, SHR, ROL, ROR, INC, DEC, NOT, and SWAP.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC157 | 2 | Quad 2:1 mux (ALU function select) |
| 74HC86 | 1 | Quad XOR (reuse from Lab 5, adds XOR op) |
| 74HC08 | 1 | Quad AND gate (AND operation) |
| 74HC32 | 1 | Quad OR gate (OR operation) |

## Concept

Lab 5 built ADD/SUB only. The full ALU needs a **result mux** that selects between:
- Adder output (ADD/SUB/ADC/SBC/INC/DEC)
- AND output (AND/ANDI/TST)
- OR output (OR/ORI)
- XOR output (XOR/XORI/NOT)
- Shift output (SHL/SHR/ROL/ROR)
- Swap output (SWAP nibbles)

```
A ──┬──► Adder ──────┐
    ├──► AND gate ───┤
    ├──► OR gate ────┼──► Result Mux ──► Result [7:0]
    ├──► XOR gate ───┤        ▲
    └──► Shift logic ┘        │
                          alu_op [2:0]
```

## New Instructions Enabled

| Opcode | Instruction | ALU Operation |
|:------:|-------------|---------------|
| 0x02 | AND rs | a0 = a0 & reg |
| 0x03 | OR rs | a0 = a0 \| reg |
| 0x04 | XOR rs | a0 = a0 ^ reg |
| 0x06 | ADC rs | a0 = a0 + reg + C |
| 0x07 | SBC rs | a0 = a0 - reg - !C |
| 0x19 | ANDI imm | a0 = a0 & imm |
| 0x1A | ORI imm | a0 = a0 \| imm |
| 0x1B | XORI imm | a0 = a0 ^ imm |
| 0x1C | TST imm | flags = a0 & imm (no write) |
| 0x40 | SHL | C=a0[7], a0 = {a0[6:0], 0} |
| 0x41 | SHR | C=a0[0], a0 = {0, a0[7:1]} |
| 0x42 | ROL | C=a0[7], a0 = {a0[6:0], old_C} |
| 0x43 | ROR | C=a0[0], a0 = {old_C, a0[7:1]} |
| 0x44 | INC | a0 = a0 + 1 |
| 0x45 | DEC | a0 = a0 - 1 |
| 0x46 | NOT | a0 = ~a0 |
| 0x47 | SWAP | a0 = {a0[3:0], a0[7:4]} |

## Schematic

```
A[7:0] (from a0) ──┬──────────────────────────────────► Adder A
                   ├──► 74HC08 (AND) ──► mux input 1
                   ├──► 74HC32 (OR)  ──► mux input 2
                   ├──► 74HC86 (XOR) ──► mux input 3
                   └──► Shift wiring  ──► mux input 4

B[7:0] (operand) ──┬──► XOR w/SUB ──► Adder B
                   ├──► 74HC08 (AND)
                   ├──► 74HC32 (OR)
                   └──► 74HC86 (XOR)

Result Mux (74HC157 ×2):
  S0,S1 from opcode decode
  00 = Adder result (ADD/SUB/ADC/SBC/INC/DEC)
  01 = AND result
  10 = OR result
  11 = XOR result (also NOT via XOR $FF)

Shift (direct wiring, no extra chips):
  SHL: result = {a0[6:0], 0}         carry_out = a0[7]
  SHR: result = {0, a0[7:1]}         carry_out = a0[0]
  ROL: result = {a0[6:0], flag_C}    carry_out = a0[7]
  ROR: result = {flag_C, a0[7:1]}    carry_out = a0[0]
  SWAP: result = {a0[3:0], a0[7:4]}

INC: Adder with B=0, C0=1 → a0 + 0 + 1 = a0 + 1
DEC: Adder with B=$FF, C0=0 → a0 + $FF + 0 = a0 - 1
NOT: XOR with B=$FF → a0 ^ $FF = ~a0

Carry-in control (for ADC/SBC):
  ADC: C0 = flag_C
  SBC: B inverted, C0 = flag_C
  ADD: C0 = 0
  SUB: B inverted, C0 = 1
```

## Procedure

1. Add 74HC08 (AND gate): wire A[7:0] and B[7:0] to inputs, outputs = AND result.
2. Add 74HC32 (OR gate): wire A and B, outputs = OR result.
3. Reuse 74HC86 (XOR): already has A and B, outputs = XOR result.
4. Add 74HC157 ×2 as result mux: select between Adder/AND/OR/XOR based on opcode decode.
5. Wire shift outputs directly (no chip needed — just reroute wires):
   - SHL: connect a0[6:0] to result[7:1], tie result[0]=0
   - SHR: connect a0[7:1] to result[6:0], tie result[7]=0
   - ROL/ROR: same but use flag_C for the shifted-in bit
6. Add carry-in mux: select C0 source based on instruction (0, 1, or flag_C).
7. Update control decode to generate alu_op[2:0] from opcode.

## Test Procedure

| Test | Program | Expected |
|:----:|---------|----------|
| 1 | LI a0,$F0 / ANDI $0F / HLT | a0 = $00 |
| 2 | LI a0,$A0 / ORI $05 / HLT | a0 = $A5 |
| 3 | LI a0,$FF / XORI $AA / HLT | a0 = $55 |
| 4 | LI a0,$81 / SHL / HLT | a0 = $02, C=1 |
| 5 | LI a0,$81 / SHR / HLT | a0 = $40, C=1 |
| 6 | SEC / LI a0,$00 / ROL / HLT | a0 = $01 (C shifted in) |
| 7 | LI a0,$05 / INC / HLT | a0 = $06 |
| 8 | LI a0,$05 / DEC / HLT | a0 = $04 |
| 9 | LI a0,$AA / NOT / HLT | a0 = $55 |
| 10 | LI a0,$A5 / SWAP / HLT | a0 = $5A |
| 11 | LI a0,$AB / TST $0F / HLT | a0 = $AB (unchanged), Z=0 |
| 12 | SEC / LI a0,$10 / LI t0,$05 / ADC t0 / HLT | a0 = $16 |

## Checkoff

- [ ] AND/OR/XOR: logic operations correct
- [ ] SHL/SHR: shift with correct carry out
- [ ] ROL/ROR: rotate through carry flag
- [ ] INC/DEC: +1/-1 without affecting carry input
- [ ] NOT: all bits inverted
- [ ] SWAP: nibbles exchanged
- [ ] TST: flags set but a0 unchanged
- [ ] ADC/SBC: carry flag used as input
- [ ] Result mux selects correct ALU function

## Notes
- Shift operations don't need extra chips — they're just rewired connections through the result mux.
- NOT is XOR with $FF. INC is ADD with B=0,C0=1. DEC is ADD with B=$FF,C0=0. These reuse existing adder hardware.
- The result mux adds 2 chips (74HC157) to the design.
- After this lab, all 8 ALU-register and 7 ALU-immediate instructions work, plus all 8 shift/unary ops.

---

## Thai Version

---

# แลป 9: ALU เต็มรูปแบบ — Logic และ Shift

---

## เป้าหมาย

ขยาย ALU ให้ทำ AND, OR, XOR, เลื่อนบิต, หมุนบิต, INC, DEC, NOT, SWAP ได้

---

## ความรู้พื้นฐาน

Lab 5 สร้างได้แค่ บวก/ลบ ตอนนี้เพิ่ม **ตัวเลือกผลลัพธ์ (Result Mux):**

| alu_op | ผลลัพธ์ที่เลือก |
|:------:|----------------|
| 00 | Adder (บวก/ลบ/INC/DEC) |
| 01 | AND (บิตที่ตรงกันเท่านั้น) |
| 10 | OR (บิตใดบิตหนึ่งเป็น 1) |
| 11 | XOR (บิตที่ต่างกัน) |

**Shift (เลื่อนบิต):** ไม่ต้องใช้ชิปเพิ่ม แค่ต่อสายใหม่:
- SHL: เลื่อนซ้าย ใส่ 0 ทางขวา
- SHR: เลื่อนขวา ใส่ 0 ทางซ้าย
- ROL/ROR: หมุนผ่าน Carry flag

**เทคนิคประหยัดชิป:**
- NOT = XOR กับ $FF
- INC = บวก 0 แล้วใส่ carry-in = 1
- DEC = บวก $FF แล้วใส่ carry-in = 0

---

## อุปกรณ์เพิ่มเติม

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC157 | 2 | เลือกผลลัพธ์ (Adder/AND/OR/XOR) |
| 74HC08 | 1 | AND operation |
| 74HC32 | 1 | OR operation |

---

## ขั้นตอนต่อวงจร

1. ต่อ 74HC08: input A กับ B → output = A AND B
2. ต่อ 74HC32: input A กับ B → output = A OR B
3. 74HC86 (มีอยู่แล้ว): output = A XOR B
4. ต่อ 74HC157 ×2 เป็น result mux: เลือก Adder/AND/OR/XOR ตาม opcode
5. ต่อสาย shift: a0[6:0]→result[7:1] (SHL), a0[7:1]→result[6:0] (SHR)
6. ต่อ carry-in mux: เลือก 0, 1, หรือ flag_C ตามคำสั่ง
7. อัพเดท decode ให้สร้าง alu_op จาก opcode

---

## ทดสอบ

| ขั้น | โปรแกรม | ผลที่ถูกต้อง |
|:----:|---------|-------------|
| 1 | LI a0,$F0 / ANDI $0F | a0 = $00 |
| 2 | LI a0,$A0 / ORI $05 | a0 = $A5 |
| 3 | LI a0,$FF / XORI $AA | a0 = $55 |
| 4 | LI a0,$81 / SHL | a0 = $02, C=1 |
| 5 | LI a0,$81 / SHR | a0 = $40, C=1 |
| 6 | LI a0,$05 / INC | a0 = $06 |
| 7 | LI a0,$05 / DEC | a0 = $04 |
| 8 | LI a0,$AA / NOT | a0 = $55 |
| 9 | LI a0,$A5 / SWAP | a0 = $5A |

---

## เช็คลิสต์ผ่าน

- [ ] AND/OR/XOR ถูกต้อง
- [ ] SHL/SHR เลื่อนบิตถูก + Carry ถูก
- [ ] ROL/ROR หมุนผ่าน Carry
- [ ] INC/DEC +1/-1 ถูกต้อง
- [ ] NOT กลับบิตทุกตัว
- [ ] SWAP สลับ nibble
- [ ] ADC/SBC ใช้ Carry flag เป็น input

---

## หมายเหตุ

- หลัง Lab นี้: คำสั่ง ALU ทั้ง 8 ตัว + ALU immediate 7 ตัว + shift/unary 8 ตัว = **23 คำสั่งทำงานได้**
- Lab ถัดไป (Lab 10) จะเพิ่ม stack สำหรับ PUSH/POP/JAL/RET
