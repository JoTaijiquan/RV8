# Lab 3: ROM and Instruction Fetch

## Objective
Connect program ROM to the PC so the CPU fetches bytes sequentially from memory.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| AT28C256 | 1 | 32KB EEPROM (program ROM) |
| 74HC138 | 1 | 3-to-8 address decoder |
| 74HC245 | 1 | Octal bus transceiver (data bus buffer) |
| LED + 330Ω | 8 | Data bus display |

## Pre-Lab
Program the AT28C256 with this test pattern (using TL866 or Pico programmer):
```
Address  Data    (Purpose)
$C000    $AA     (10101010 — alternating bits)
$C001    $55     (01010101 — complement)
$C002    $01     (ascending)
$C003    $02
$C004    $04
$C005    $08
$C006    $10
$C007    $20
$C008    $40
$C009    $80
$C00A    $FF     (all ones)
$C00B    $00     (all zeros)
```

## Schematic

```
PC A[14:0] ──────────────────────► AT28C256 A[14:0]
PC A[15] ────────────────────────► 74HC138 input A (for decode)
PC A[14] ────────────────────────► 74HC138 input B
PC A[13] ────────────────────────► 74HC138 input C

74HC138:
  G1 = VCC, /G2A = GND, /G2B = GND
  /Y6 + /Y7 → ROM /CE (active when A[15:13] = 110 or 111)

AT28C256:
  A[14:0] ← PC
  /CE ← decode output
  /OE ← GND (always reading for now)
  D[7:0] → 74HC245 A-side

74HC245:
  A[7:0] ← ROM D[7:0]
  B[7:0] → data bus → LEDs
  DIR = VCC (A→B, ROM to bus)
  /OE = GND (always enabled for now)
```

## Simulate First

```bash
cd sim/
iverilog -o lab3 lab3_rom_tb.v && vvp lab3
gtkwave lab3.vcd
```

**What to check in GTKWave:**
- `pc`: counts up
- `data_bus`: shows ROM contents matching the test pattern ($AA, $55, $01...)
- Each clock cycle fetches the next byte

---

## Procedure

1. Insert AT28C256 (pre-programmed). Connect VCC (pin 28) and GND (pin 14).
2. Wire PC outputs A0–A14 to ROM address pins A0–A14.
3. Insert 74HC138. Wire A15→A, A14→B, A13→C. Tie G1=VCC, /G2A=/G2B=GND.
4. Connect 74HC138 /Y6 and /Y7 (OR together with a wire-AND or gate) to ROM /CE.
   - Simple: just connect /Y7 to ROM /CE (covers $E000-$FFFF).
   - Or tie ROM /CE to GND for now (always selected) since PC starts at $0000 but ROM responds to all addresses when /CE=LOW.
5. Tie ROM /OE to GND (always outputting).
6. Insert 74HC245. Wire ROM D[7:0] to A-side. B-side is the data bus.
7. Tie 74HC245 DIR=VCC (A→B), /OE=GND.
8. Connect 8 LEDs to data bus (B-side of 245).

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | Press RESET, then single-step 1× | LEDs show $AA (10101010) |
| 2 | Step again | LEDs show $55 (01010101) |
| 3 | Step again | LEDs show $01 (00000001) |
| 4 | Continue stepping | Pattern: $02, $04, $08, $10, $20, $40, $80 |
| 5 | Step to byte 10 | LEDs show $FF (all on) |
| 6 | Step to byte 11 | LEDs show $00 (all off) |
| 7 | Press RESET | Back to $AA on next step |
| 8 | RUN mode | LEDs blur (fetching at 3.5 MHz) |

## Checkoff

- [ ] Data bus shows correct ROM contents in sequence
- [ ] Reset returns to first byte
- [ ] All 8 data bits correct (verify $AA and $55 carefully)
- [ ] No bus contention (245 drives cleanly)

## Notes
- The PC starts at $0000 but ROM is mapped at $C000+. For this test, either:
  - Program ROM so address $0000 has $AA (ignore mapping), OR
  - Pre-load PC to $C000 by tying some /LD inputs (advanced), OR
  - Just tie ROM /CE low so it responds to all addresses (simplest for testing)
- In the final build, the PC will start at the reset vector ($FFFC) which points to $C000.
- The 74HC245 will later be controlled by /RD signal. For now it's always on.

## Thai Version

---

# แลป 3: ROM และการอ่านคำสั่ง (Instruction Fetch)

---

## เป้าหมาย

ต่อ ROM เข้ากับ PC เพื่อให้ระบบอ่านข้อมูลจากหน่วยความจำได้ — นี่คือครั้งแรกที่ CPU "อ่านโปรแกรม" ได้จริง

---

## ความรู้พื้นฐาน

**ROM (AT28C256)** = หนังสือคำสั่ง เก็บโปรแกรมไว้ 32,768 ไบต์

**Instruction Fetch** = การอ่านคำสั่ง ทำงานแบบนี้ทุก clock:
1. PC ส่งตำแหน่ง (Address) ไปที่ ROM
2. ROM ส่งข้อมูล (Data) กลับมา
3. PC เพิ่ม 1 → อ่านตำแหน่งถัดไป

**74HC245** = ตัวขับสัญญาณ ส่งข้อมูลจาก ROM ไปยัง Data Bus

**74HC138** = ตัวถอดรหัส Address เลือกว่าจะใช้ ROM หรืออุปกรณ์อื่น

---

## อุปกรณ์

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| AT28C256 | 1 | ROM เก็บโปรแกรม (32KB) |
| 74HC138 | 1 | ถอดรหัส Address เลือก ROM |
| 74HC245 | 1 | Buffer ส่งข้อมูลไป Data Bus |
| LED + 330Ω | 8 | แสดงข้อมูล 8 บิตบน Data Bus |

---

## เตรียมก่อนทำ: โปรแกรม ROM

ใช้เครื่องโปรแกรม (TL866 หรือ Pico) เขียนค่าทดสอบลง ROM:

```
ตำแหน่ง   ค่า      LED ที่ต้องเห็น
$0000     $AA      ○●○●○●○●
$0001     $55      ●○●○●○●○
$0002     $01      ●○○○○○○○
$0003     $02      ○●○○○○○○
$0004     $04      ○○●○○○○○
$0005     $08      ○○○●○○○○
$0006     $10      ○○○○●○○○
$0007     $20      ○○○○○●○○
$0008     $40      ○○○○○○●○
$0009     $80      ○○○○○○○●
$000A     $FF      ●●●●●●●●
$000B     $00      ○○○○○○○○
```
(● = LED ติด, ○ = LED ดับ)

---

## ผังวงจร

```
PC [A0–A14] ──────────────► ROM [A0–A14]

                              ROM [D0–D7]
                                  │
                              74HC245
                                  │
                              Data Bus ──► LED 8 ดวง

ROM /CE ← GND (เลือกตลอด สำหรับทดสอบ)
ROM /OE ← GND (อ่านตลอด)
74HC245 DIR ← VCC (A→B)
74HC245 /OE ← GND (เปิดตลอด)
```

---

## ขั้นตอนต่อวงจร

1. เสียบ AT28C256 (ที่โปรแกรมแล้ว) ต่อ VCC (pin 28) และ GND (pin 14)
2. ต่อ PC output A0–A14 → ROM address A0–A14
3. ต่อ ROM /CE → GND (เลือก ROM ตลอดเวลา สำหรับทดสอบ)
4. ต่อ ROM /OE → GND (อ่านตลอด)
5. เสียบ 74HC245 ต่อ VCC/GND
6. ต่อ ROM D0–D7 → 74HC245 ฝั่ง A
7. ต่อ 74HC245 DIR → VCC, /OE → GND
8. ต่อ LED 8 ดวง ที่ 74HC245 ฝั่ง B (Data Bus)

---

## ทดสอบ (ใช้ STEP mode จาก Lab 1)

| ขั้น | ทำอะไร | ผลที่ถูกต้อง |
|:----:|--------|-------------|
| 1 | กด RESET แล้วกด STEP 1 ครั้ง | LED แสดง $AA (สลับติดดับ) |
| 2 | กด STEP อีกครั้ง | LED แสดง $55 (สลับกลับ) |
| 3 | กด STEP อีกครั้ง | LED แสดง $01 (ดวงเดียวติด) |
| 4 | กด STEP ต่อไปเรื่อยๆ | LED เลื่อนไปทีละดวง: $02, $04, $08... |
| 5 | กด STEP ถึงไบต์ที่ 10 | LED ติดหมด ($FF) |
| 6 | กด STEP อีกครั้ง | LED ดับหมด ($00) |
| 7 | กด RESET | กลับไปเริ่มที่ $AA |
| 8 | เลื่อนไป RUN mode | LED พร่ามัว (อ่านเร็วมาก) |

---

## เช็คลิสต์ผ่าน

- [ ] Data Bus แสดงค่าจาก ROM ตามลำดับถูกต้อง
- [ ] กด RESET แล้วกลับไปไบต์แรก
- [ ] ค่า $AA และ $55 ถูกต้องทุกบิต (ตรวจ LED ทีละดวง)
- [ ] ไม่มีสัญญาณรบกวน (LED ไม่กระพริบผิดปกติ)

---

## จำลองก่อนต่อจริง (ถ้ามีคอมพิวเตอร์)

```bash
cd sim/
iverilog -o lab3 lab3_rom_tb.v && vvp lab3
gtkwave lab3.vcd
```

ดู: `pc` เพิ่มทีละ 1, `data_bus` แสดงค่า $AA, $55, $01, $02... ตามลำดับ

---

## หมายเหตุ

- ใน Lab นี้ต่อ ROM /CE ลง GND ตรงๆ (ง่ายสุด) — ในวงจรจริงจะใช้ 74HC138 ถอดรหัส Address
- PC เริ่มที่ $0000 แต่ ROM จริงอยู่ที่ $C000+ — ตอนทดสอบเราโปรแกรมค่าที่ตำแหน่ง $0000 ไว้เลย
- Lab ถัดไป (Lab 4) จะเก็บข้อมูลที่อ่านได้ลงใน Instruction Register
