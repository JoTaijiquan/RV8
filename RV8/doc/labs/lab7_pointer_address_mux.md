# Lab 7: Pointer Register and Address Mux

## Objective
Build the 16-bit pointer register and address multiplexer to access RAM.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC161 | 2 | 4-bit counter (pointer low/high with auto-increment) |
| 74HC157 | 2 | Quad 2:1 mux (address source select) |
| 62256 | 1 | 32KB static RAM |
| LED + 330Ω | 8 | Data bus (reuse from earlier) |

## Concept

The address bus can be driven by different sources:
```
addr_sel=0: PC      → fetch instructions from ROM
addr_sel=1: pointer → read/write data in RAM
```

The pointer register {ph, pl} holds a 16-bit address and can auto-increment.

## Schematic

```
U11 (pl, pointer low):
  D[3:0] ← data bus [3:0] (for loading)
  /LD ← pl_load
  ENT ← ptr_inc
  ENP ← ptr_inc
  CLK ← CLK
  Q[3:0] → mux input B (low nibble)
  TC → U12.ENT (carry to high)

U12 (ph, pointer high):
  D[3:0] ← data bus [3:0]
  /LD ← ph_load
  ENT ← U11.TC
  ENP ← ptr_inc
  CLK ← CLK
  Q[3:0] → mux input B (high nibble)

U16 (address mux low byte):
  1A[3:0] = PC[3:0],  1B[3:0] = pl[3:0]
  2A[3:0] = PC[7:4],  2B[3:0] = pl[7:4]*
  S = addr_sel
  Y → address bus [7:0]

U17 (address mux high byte):
  1A[3:0] = PC[11:8], 1B[3:0] = ph[3:0]
  2A[3:0] = PC[15:12],2B[3:0] = ph[7:4]*
  S = addr_sel
  Y → address bus [15:8]

* Note: 74HC161 is 4-bit. Full 8-bit pointer needs 4× 161 total.
  For this lab, use 4-bit pointer (256-byte range) to keep it simple.
  Final build uses cascaded pairs.

62256 RAM:
  A[14:0] ← address bus
  D[7:0] ↔ data bus
  /CE ← decode (active for $0000-$7FFF)
  /OE ← /RD
  /WE ← /WR
```

## Simulate First

```bash
cd sim/
iverilog -o lab7 lab7_pointer_tb.v && vvp lab7
gtkwave lab7.vcd
```

**What to check in GTKWave:**
- `addr_bus`: switches between PC and pointer based on `addr_sel`
- `ptr`: loads $2000, increments to $2001
- RAM write/read: $42 stored and retrieved correctly

---

## Procedure

1. Insert U11, U12 (74HC161). Connect VCC/GND.
2. Wire U11 TC → U12 ENT (carry chain).
3. Insert U16, U17 (74HC157). Connect VCC/GND.
4. Wire PC outputs to mux "A" inputs (addr_sel=0 selects PC).
5. Wire pointer outputs to mux "B" inputs (addr_sel=1 selects pointer).
6. Wire mux Y outputs to address bus.
7. Add addr_sel toggle switch to mux S pins.
8. Insert 62256 RAM. Wire address bus to A[14:0], data bus to D[7:0].
9. Wire RAM /CE to address decode (or tie LOW for testing).
10. Add /RD and /WR manual pushbuttons for RAM control.

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | addr_sel=0 (PC mode) | Address bus shows PC count (ROM fetch works as before) |
| 2 | addr_sel=1 (pointer mode) | Address bus shows pointer value |
| 3 | Load pointer with $2000 (ph=$20, pl=$00) | Address bus = $2000 |
| 4 | Put $42 on data bus, pulse /WR | RAM[$2000] = $42 |
| 5 | Release data bus, pulse /RD | Data bus shows $42 (read back) |
| 6 | Pulse ptr_inc | Address becomes $2001 |
| 7 | Write $55 to $2001, read back | Data bus shows $55 |
| 8 | Switch to addr_sel=0 | Back to PC/ROM fetch mode |

## Checkoff

- [ ] Address mux selects PC (S=0) or pointer (S=1) correctly
- [ ] Pointer loads a value and outputs it to address bus
- [ ] Pointer auto-increments with carry (pl→ph)
- [ ] RAM write + read back works at pointer address
- [ ] Switching between PC and pointer doesn't corrupt either

## Notes
- In the final CPU, addr_sel is controlled by the state machine (S0/S1 = PC for fetch, S2 = pointer for load/store).
- The full address mux has more sources (stack, zero-page, page-relative). This lab tests the two most important: PC and pointer.
- RAM and ROM coexist on the same data bus — the address decode ensures only one responds at a time.

## Thai Version

---

# แลป 7: Pointer Register และ Address Mux

---

## เป้าหมาย

สร้าง pointer 16 บิตและตัวเลือก address เพื่อให้ CPU อ่าน/เขียน RAM ได้

---

## ความรู้พื้นฐาน

**Pointer {ph, pl}** = ตัวชี้ตำแหน่งใน RAM ใช้สำหรับอ่าน/เขียนข้อมูล

**Address Mux** = สวิตช์เลือกว่า address bus จะมาจากไหน:
- addr_sel = 0 → ใช้ PC (อ่านคำสั่งจาก ROM)
- addr_sel = 1 → ใช้ pointer (อ่าน/เขียนข้อมูลใน RAM)

**RAM (62256)** = หน่วยความจำ 32KB สำหรับเก็บข้อมูล (ตัวแปร, stack)

**Auto-increment** = pointer เพิ่มค่าอัตโนมัติหลังใช้งาน (สำหรับอ่านข้อมูลต่อเนื่อง)

---

## อุปกรณ์

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC161 | 2 | pointer low + high (นับ + โหลดค่า) |
| 74HC157 | 2 | เลือก address (PC หรือ pointer) |
| 62256 | 1 | RAM 32KB |
| LED + 330Ω | 8 | แสดง Data Bus |

---

## ผังวงจร

```
        ┌─── PC [15:0] ───┐
        │                  ▼
        │            ┌──────────┐
        │            │ 74HC157  │
        │            │ addr mux │──► Address Bus ──► RAM + ROM
        │            └──────────┘
        │                  ▲
        └─── Pointer ──────┘
             {ph, pl}
                ▲
           addr_sel (0=PC, 1=Pointer)


RAM 62256:
  Address ← Address Bus
  Data ↔ Data Bus
  /WR ← ปุ่มเขียน
  /RD ← ปุ่มอ่าน
```

---

## ขั้นตอนต่อวงจร

1. เสียบ U11, U12 (74HC161 สำหรับ pointer) ต่อ VCC/GND
2. ต่อ U11 TC → U12 ENT (ทดจาก pl ไป ph)
3. เสียบ U16, U17 (74HC157 address mux) ต่อ VCC/GND
4. ต่อ PC output → mux input A (addr_sel=0 เลือก PC)
5. ต่อ pointer output → mux input B (addr_sel=1 เลือก pointer)
6. ต่อ mux output → Address Bus
7. ต่อสวิตช์ addr_sel → mux pin S
8. เสียบ 62256 RAM ต่อ Address Bus และ Data Bus
9. ต่อ RAM /CE → GND (หรือผ่าน decode)
10. ต่อปุ่ม /RD และ /WR สำหรับควบคุม RAM

---

## ทดสอบ

| ขั้น | ทำอะไร | ผลที่ถูกต้อง |
|:----:|--------|-------------|
| 1 | addr_sel = 0 (PC mode) | Address Bus แสดงค่า PC (ROM fetch ทำงานเหมือนเดิม) |
| 2 | addr_sel = 1 (pointer mode) | Address Bus แสดงค่า pointer |
| 3 | โหลด pointer = $2000 | Address Bus = $2000 |
| 4 | ใส่ $42 บน Data Bus, กด /WR | เขียน $42 ลง RAM ตำแหน่ง $2000 |
| 5 | ปล่อย Data Bus, กด /RD | LED แสดง $42 (อ่านกลับ) |
| 6 | กด ptr_inc | Address เปลี่ยนเป็น $2001 |
| 7 | เขียน $55 ที่ $2001 แล้วอ่านกลับ | LED แสดง $55 |
| 8 | เลื่อน addr_sel = 0 | กลับไป PC/ROM mode |

---

## เช็คลิสต์ผ่าน

- [ ] Address mux เลือก PC (S=0) หรือ pointer (S=1) ถูกต้อง
- [ ] Pointer โหลดค่าและแสดงบน Address Bus
- [ ] Pointer auto-increment ทำงาน (ทดจาก pl→ph)
- [ ] เขียน RAM แล้วอ่านกลับได้ค่าเดิม
- [ ] สลับระหว่าง PC กับ pointer ไม่เสียค่า

---

## จำลองก่อนต่อจริง

```bash
cd sim/
iverilog -o lab7 lab7_pointer_tb.v && vvp lab7
gtkwave lab7.vcd
```

---

## หมายเหตุ

- ใน CPU จริง addr_sel ถูกควบคุมโดย state machine (fetch ใช้ PC, load/store ใช้ pointer)
- Address mux เต็มรูปแบบมีหลาย source: PC, pointer, stack, zero-page, page-relative
- Lab ถัดไป (Lab 8) จะต่อ Control Unit เพื่อให้ CPU ทำงานเองอัตโนมัติ
