# Lab 2: Program Counter

## Objective
Build a 16-bit program counter that increments on each clock cycle and resets to $0000.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC161 | 4 | 4-bit synchronous counter |
| LED + 330Ω | 8 | Address bus low byte display |

## Schematic

```
U1 (PC bits 3:0)    U2 (PC bits 7:4)    U3 (PC bits 11:8)   U4 (PC bits 15:12)
┌──────────┐        ┌──────────┐        ┌──────────┐        ┌──────────┐
│CLK ← CLK │        │CLK ← CLK │        │CLK ← CLK │        │CLK ← CLK │
│/CLR← /RST│        │/CLR← /RST│        │/CLR← /RST│        │/CLR← /RST│
│/LD ← VCC │        │/LD ← VCC │        │/LD ← VCC │        │/LD ← VCC │
│ENT ← VCC │        │ENT ← U1.TC│       │ENT ← U2.TC│       │ENT ← U3.TC│
│ENP ← VCC │        │ENP ← VCC │        │ENP ← VCC │        │ENP ← VCC │
│QA → A0   │        │QA → A4   │        │QA → A8   │        │QA → A12  │
│QB → A1   │        │QB → A5   │        │QB → A9   │        │QB → A13  │
│QC → A2   │        │QC → A6   │        │QC → A10  │        │QC → A14  │
│QD → A3   │        │QD → A7   │        │QD → A11  │        │QD → A15  │
│TC → U2.ENT│       │TC → U3.ENT│       │TC → U4.ENT│       │TC → (nc) │
└──────────┘        └──────────┘        └──────────┘        └──────────┘
```

## Simulate First

```bash
cd sim/
iverilog -o lab2 lab2_pc_tb.v && vvp lab2
gtkwave lab2.vcd
```

**What to check in GTKWave:**
- `pc[15:0]`: increments by 1 each clock
- Carry propagation: pc rolls from $000F → $0010, $00FF → $0100
- Reset: pc snaps to $0000

---

## Procedure

1. Place U1–U4 on breadboard. Connect VCC (pin 16) and GND (pin 8) on each.
2. Connect CLK (from Lab 1) to all four CLK inputs (pin 2).
3. Connect /RST (from Lab 1) to all four /CLR inputs (pin 1).
4. Tie /LD (pin 9) HIGH on all four chips (no parallel load yet).
5. U1: tie ENT (pin 10) and ENP (pin 7) to VCC.
6. U2: connect ENT (pin 10) to U1 TC (pin 15). Tie ENP to VCC.
7. U3: connect ENT to U2 TC. Tie ENP to VCC.
8. U4: connect ENT to U3 TC. Tie ENP to VCC.
9. Connect LEDs to U1 and U2 outputs (A0–A7) for visual feedback.

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | Press RESET | All LEDs off (PC = $0000) |
| 2 | Single-step 1× | A0 LED on (PC = $0001) |
| 3 | Single-step 15× total | A0-A3 all on (PC = $000F) |
| 4 | Single-step 1 more | A0-A3 off, A4 on (PC = $0010) — carry! |
| 5 | Single-step to $00FF | All 8 LEDs on |
| 6 | Single-step 1 more | All off (PC = $0100) — verify U3 increments |
| 7 | Switch to RUN mode | LEDs blur (counting too fast to see) |
| 8 | Press RESET during RUN | All LEDs off immediately |

## Checkoff

- [ ] PC counts 0000 → 0001 → 0002 ... sequentially
- [ ] Carry propagates: U1→U2→U3→U4
- [ ] /RST resets all counters to 0000
- [ ] No glitches on carry transitions (check with scope on U2.QA)

## Notes
- Later we'll connect /LD to load branch targets and ENP/ENT to a control signal for halting.
- For now, the PC just free-runs. This is enough to test ROM fetching in Lab 3.

## Thai Version

---

# แลป 2: Program Counter (ตัวนับตำแหน่งคำสั่ง)

---

## เป้าหมาย

สร้างตัวนับ 16 บิตที่เพิ่มค่าทีละ 1 ทุก clock — ใช้ชี้ตำแหน่งคำสั่งใน ROM

---

## ความรู้พื้นฐาน

**Program Counter (PC)** = ที่คั่นหนังสือของ CPU บอกว่า "ตอนนี้อ่านคำสั่งอยู่ตำแหน่งไหน"
- ทุก clock: PC เพิ่ม 1 → อ่านคำสั่งถัดไป
- กด Reset: PC กลับเป็น 0 → เริ่มอ่านจากต้น
- 16 บิต = นับได้ 0 ถึง 65,535 (64KB หน่วยความจำ)

**74HC161** = ชิปนับ 4 บิต (นับ 0–15) ใช้ 4 ตัวต่อกันได้ 16 บิต

**Carry (ทด)** = เมื่อตัวแรกนับครบ 15→0 จะส่งสัญญาณให้ตัวถัดไปเพิ่ม 1 (เหมือนทดเลข)

---

## อุปกรณ์

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC161 | 4 | ตัวนับ 4 บิต × 4 = 16 บิต |
| LED + 330Ω | 8 | แสดงค่า PC บิตต่ำ (A0–A7) |

---

## ผังวงจร

```
CLK (จาก Lab 1) ──────► U1, U2, U3, U4 (ขา 2)
/RST (จาก Lab 1) ─────► U1, U2, U3, U4 (ขา 1)

U1 [PC 3:0]         U2 [PC 7:4]         U3 [PC 11:8]        U4 [PC 15:12]
┌──────────┐        ┌──────────┐        ┌──────────┐        ┌──────────┐
│ ENT ← VCC│        │ ENT ← U1.TC│      │ ENT ← U2.TC│      │ ENT ← U3.TC│
│ ENP ← VCC│        │ ENP ← VCC │       │ ENP ← VCC │       │ ENP ← VCC │
│ /LD ← VCC│        │ /LD ← VCC │       │ /LD ← VCC │       │ /LD ← VCC │
│           │        │           │       │           │        │           │
│ QA → A0  │        │ QA → A4   │       │ QA → A8   │        │ QA → A12  │
│ QB → A1  │        │ QB → A5   │       │ QB → A9   │        │ QB → A13  │
│ QC → A2  │        │ QC → A6   │       │ QC → A10  │        │ QC → A14  │
│ QD → A3  │        │ QD → A7   │       │ QD → A11  │        │ QD → A15  │
│ TC ───────────────►│           │       │           │        │           │
└──────────┘        │ TC ───────────────►│           │        │           │
                    └──────────┘        │ TC ───────────────►│           │
                                        └──────────┘        └──────────┘
```

---

## ขาสำคัญของ 74HC161

| ขา | ชื่อ | ต่อกับอะไร |
|:--:|------|-----------|
| 16 | VCC | +5V |
| 8 | GND | GND |
| 2 | CLK | CLK จาก Lab 1 |
| 1 | /CLR | /RST จาก Lab 1 |
| 9 | /LD | +5V (ยังไม่ใช้โหลด) |
| 7 | ENP | +5V |
| 10 | ENT | VCC (U1) หรือ TC ของตัวก่อนหน้า |
| 15 | TC | ต่อไป ENT ของตัวถัดไป |
| 3–6 | QA–QD | Output 4 บิต |

---

## ขั้นตอนต่อวงจร

1. เสียบ U1–U4 ลง breadboard ต่อ VCC (pin 16) และ GND (pin 8) ทุกตัว
2. ต่อ CLK จาก Lab 1 → pin 2 ของทุกตัว
3. ต่อ /RST จาก Lab 1 → pin 1 ของทุกตัว
4. ต่อ /LD (pin 9) → +5V ทุกตัว
5. U1: ต่อ ENT (pin 10) และ ENP (pin 7) → +5V
6. U2: ต่อ ENT (pin 10) ← U1 TC (pin 15) ต่อ ENP → +5V
7. U3: ต่อ ENT ← U2 TC ต่อ ENP → +5V
8. U4: ต่อ ENT ← U3 TC ต่อ ENP → +5V
9. ต่อ LED 8 ดวงกับ output ของ U1 และ U2 (A0–A7)

---

## ทดสอบ (ใช้ STEP mode จาก Lab 1)

| ขั้น | ทำอะไร | ผลที่ถูกต้อง |
|:----:|--------|-------------|
| 1 | กด RESET | LED ดับหมด (PC = 0000) |
| 2 | กด STEP 1 ครั้ง | LED A0 ติด (PC = 0001) |
| 3 | กด STEP จนครบ 15 ครั้ง | LED A0–A3 ติดหมด (PC = 000F) |
| 4 | กด STEP อีก 1 ครั้ง | A0–A3 ดับ, A4 ติด (PC = 0010) ← ทด! |
| 5 | กด STEP จนถึง $00FF | LED 8 ดวงติดหมด |
| 6 | กด STEP อีก 1 ครั้ง | LED ดับหมด (PC = 0100) ← ทดไป U3 |
| 7 | เลื่อนไป RUN mode | LED พร่ามัว (นับเร็วเกินเห็น) |
| 8 | กด RESET ขณะ RUN | LED ดับทันที |

---

## เช็คลิสต์ผ่าน

- [ ] PC นับ 0000 → 0001 → 0002 ... ถูกต้อง
- [ ] ทดจาก U1→U2→U3→U4 ทำงาน
- [ ] กด RESET แล้ว PC กลับเป็น 0000
- [ ] ไม่มี glitch ตอนทด (ตรวจด้วย scope ที่ U2 pin 3)

---

## จำลองก่อนต่อจริง (ถ้ามีคอมพิวเตอร์)

```bash
cd sim/
iverilog -o lab2 lab2_pc_tb.v && vvp lab2
gtkwave lab2.vcd
```

ดู: `pc[15:0]` ต้องเพิ่มทีละ 1, ทดจาก $000F→$0010 และ $00FF→$0100 ถูกต้อง

---

## หมายเหตุ

- ตอนนี้ /LD ต่อ HIGH (ยังไม่โหลดค่า) — ใน Lab หลังๆ จะใช้ /LD สำหรับ JMP และ Branch
- ENP/ENT จะถูกควบคุมโดย Control Unit ใน Lab 8 เพื่อหยุด PC ตอน execute
- Lab ถัดไป (Lab 3) จะต่อ PC เข้ากับ ROM เพื่ออ่านคำสั่งจริง
