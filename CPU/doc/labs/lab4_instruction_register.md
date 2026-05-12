# Lab 4: Instruction Register

## Objective
Latch the opcode (byte 0) and operand (byte 1) of each 2-byte instruction into separate registers.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC574 | 2 | Octal D flip-flop (edge-triggered) |
| 74HC74 | 1 | Dual D flip-flop (state toggle) |
| LED + 330Ω | 8 | Opcode display (optional, reuse data bus LEDs) |

## Concept

RV8 instructions are 2 bytes. The CPU alternates between two states:
- **S0**: fetch opcode → latch into IR0 (U5)
- **S1**: fetch operand → latch into IR1 (U6)

A single flip-flop toggles between S0 and S1 each clock cycle.

## Schematic

```
74HC74 (one flip-flop used as toggle):
  D ← /Q (feeds back inverted output)
  CLK ← CLK
  /CLR ← /RST
  Q = state (0=S0, 1=S1)

U5 (IR opcode, 74HC574):
  D[7:0] ← data bus
  CLK ← CLK AND (state==0)    [= CLK when Q=LOW]
  /OE ← GND

U6 (IR operand, 74HC574):
  D[7:0] ← data bus
  CLK ← CLK AND (state==1)    [= CLK when Q=HIGH]
  /OE ← GND

Clock gating (use AND gate or NAND):
  ir0_clk = CLK AND /Q    (active during S0)
  ir1_clk = CLK AND Q     (active during S1)
  (Can use 74HC08 AND gate, or wire with a NAND trick)
```

## Simulate First

```bash
cd sim/
iverilog -o lab4 lab4_ir_tb.v && vvp lab4
gtkwave lab4.vcd
```

**What to check in GTKWave:**
- `state`: toggles 0→1→0→1...
- `ir_opcode`: latches on even cycles ($11, $16, $FF)
- `ir_operand`: latches on odd cycles ($05, $03, $00)
- Each instruction pair captured correctly

---

## Procedure

1. Insert 74HC74. Use one flip-flop as toggle: wire /Q back to D.
2. Connect CLK to 74HC74 CLK. Connect /RST to /CLR.
3. Q output = state signal. /Q = complement.
4. Insert U5 (74HC574). D inputs from data bus. CLK = (CLK AND /Q).
   - For clock gating: use one gate from a 74HC08 (AND), or for this test, manually wire.
   - Simple alternative: connect U5.CLK to /Q (latches on falling edge of state).
5. Insert U6 (74HC574). D inputs from data bus. CLK = (CLK AND Q).
   - Or connect U6.CLK to Q.
6. Tie both /OE pins to GND.
7. Add LEDs to U5 outputs (opcode) and U6 outputs (operand).

## Pre-Lab
Program ROM with known instruction pairs:
```
$0000: $11 $05    ; LI a0, 5    (opcode=$11, operand=$05)
$0002: $16 $03    ; ADDI 3      (opcode=$16, operand=$03)
$0004: $FF $00    ; HLT         (opcode=$FF, operand=$00)
```

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | RESET | State=S0, both IR cleared |
| 2 | Step 1× | U5 latches $11 (opcode), state→S1 |
| 3 | Step 1× | U6 latches $05 (operand), state→S0 |
| 4 | Step 1× | U5 latches $16 (next opcode), state→S1 |
| 5 | Step 1× | U6 latches $03 (next operand), state→S0 |
| 6 | Step 1× | U5 latches $FF (HLT opcode) |
| 7 | RESET | U5 and U6 return to first instruction |

## Checkoff

- [ ] U5 latches only on S0 (even cycles)
- [ ] U6 latches only on S1 (odd cycles)
- [ ] Opcode and operand match ROM contents
- [ ] State toggles cleanly (no double-clocking)
- [ ] RESET clears state to S0

## Notes
- In the final CPU, the state machine is more complex (S0→S1→S2→...) for multi-cycle instructions. This 2-state version is sufficient for fetch testing.
- The 74HC08 AND gate for clock gating will be part of U22 in the final build.
- U5 outputs (opcode bits) will later drive the control unit decode logic.

## Thai Version

---

# แลป 4: Instruction Register (ตัวเก็บคำสั่ง)

---

## เป้าหมาย

เก็บ opcode (ไบต์ที่ 1) และ operand (ไบต์ที่ 2) ของคำสั่งแยกกันคนละตัว

---

## ความรู้พื้นฐาน

**คำสั่ง RV8 มี 2 ไบต์เสมอ:**
- ไบต์แรก = **opcode** (บอกว่าทำอะไร เช่น บวก, ลบ, กระโดด)
- ไบต์ที่สอง = **operand** (บอกว่าทำกับอะไร เช่น ค่า 5, register t0)

**74HC574** = ตัวเก็บค่า 8 บิต เมื่อ CLK กระพริบจะจำค่าที่อยู่บน Data Bus

**State (สถานะ)** = CPU สลับไปมาระหว่าง:
- S0: อ่าน opcode → เก็บใน U5
- S1: อ่าน operand → เก็บใน U6

---

## อุปกรณ์

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC574 | 2 | เก็บ opcode (U5) และ operand (U6) |
| 74HC74 | 1 | สร้างสัญญาณสลับ S0/S1 |
| LED + 330Ω | 8 | แสดงค่า opcode |

---

## ผังวงจร

```
                    74HC74 (toggle)
                    D ← /Q (ต่อกลับ)
                    CLK ← CLK
                    Q = state (0=S0, 1=S1)
                        │
            ┌───────────┼───────────┐
            ▼                       ▼
  U5 (opcode)              U6 (operand)
  CLK = CLK AND /Q         CLK = CLK AND Q
  D ← Data Bus             D ← Data Bus
  Q → LED + ไปถอดรหัส      Q → ไปใช้เป็นค่า
```

---

## เตรียมก่อนทำ: โปรแกรม ROM

```
ตำแหน่ง   ค่า      ความหมาย
$0000     $11      opcode: LI a0
$0001     $05      operand: ค่า 5
$0002     $16      opcode: ADDI
$0003     $03      operand: ค่า 3
$0004     $FF      opcode: HLT
$0005     $00      operand: (ไม่ใช้)
```

---

## ขั้นตอนต่อวงจร

1. เสียบ 74HC74 ต่อ /Q กลับไป D (สร้าง toggle) ต่อ CLK และ /RST
2. เสียบ U5 (74HC574) ต่อ D จาก Data Bus, CLK = CLK AND /Q
3. เสียบ U6 (74HC574) ต่อ D จาก Data Bus, CLK = CLK AND Q
4. ต่อ /OE ของทั้งสองตัว → GND
5. ต่อ LED ที่ output ของ U5 (แสดง opcode)

---

## ทดสอบ (ใช้ STEP mode)

| ขั้น | ทำอะไร | ผลที่ถูกต้อง |
|:----:|--------|-------------|
| 1 | กด RESET | State = S0 |
| 2 | กด STEP 1 ครั้ง | U5 เก็บ $11 (opcode), state → S1 |
| 3 | กด STEP 1 ครั้ง | U6 เก็บ $05 (operand), state → S0 |
| 4 | กด STEP 1 ครั้ง | U5 เก็บ $16 (opcode ถัดไป) |
| 5 | กด STEP 1 ครั้ง | U6 เก็บ $03 (operand ถัดไป) |
| 6 | กด STEP 1 ครั้ง | U5 เก็บ $FF (HLT) |
| 7 | กด RESET | กลับไปคำสั่งแรก |

---

## เช็คลิสต์ผ่าน

- [ ] U5 เก็บค่าเฉพาะตอน S0 (cycle คู่)
- [ ] U6 เก็บค่าเฉพาะตอน S1 (cycle คี่)
- [ ] ค่าที่เก็บตรงกับ ROM
- [ ] State สลับสะอาด ไม่กระพริบซ้ำ
- [ ] RESET ทำให้ state กลับเป็น S0

---

## จำลองก่อนต่อจริง

```bash
cd sim/
iverilog -o lab4 lab4_ir_tb.v && vvp lab4
gtkwave lab4.vcd
```

---

## หมายเหตุ

- ใน CPU จริง state machine ซับซ้อนกว่านี้ (มีหลาย state สำหรับ memory access)
- Output ของ U5 (opcode) จะไปเข้า Control Unit ใน Lab 8
- Lab ถัดไป (Lab 5) จะสร้าง ALU สำหรับคำนวณ
