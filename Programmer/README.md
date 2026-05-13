# Programmer Board — ESP32 NodeMCU

**Purpose**: Flash ROM + UART terminal for all RV8 family CPUs
**Connection**: ESP32 ←USB→ PC | ESP32 ←40-pin bus→ CPU board

---

## Overview

```
PC ←──USB──→ [ESP32 NodeMCU] ←──40-pin ribbon──→ [CPU Board]
                    │
              [PROG/RUN switch]
```

One ESP32 NodeMCU module + 40-pin IDC connector + 1 switch. That's the whole board.

---

## Modes

| Mode | Switch | What happens |
|------|:------:|-------------|
| **PROG** | PROG | ESP32 holds /RST low, drives address+data, writes ROM |
| **RUN** | RUN | ESP32 releases /RST, listens on slot, UART bridge to PC |

---

## ESP32 NodeMCU Pin Mapping

### Data Bus (D[7:0]) — bidirectional, used in both modes

| ESP32 GPIO | Bus Pin | Signal |
|:----------:|:-------:|--------|
| GPIO 32 | 29 | D0 |
| GPIO 33 | 30 | D1 |
| GPIO 25 | 31 | D2 |
| GPIO 26 | 32 | D3 |
| GPIO 27 | 33 | D4 |
| GPIO 14 | 34 | D5 |
| GPIO 12 | 35 | D6 |
| GPIO 13 | 36 | D7 |

### Address Bus (A[15:0]) — output, PROG mode only (RV8/RV801)

| ESP32 GPIO | Bus Pin | Signal |
|:----------:|:-------:|--------|
| GPIO 15 | 21 | A0 |
| GPIO 2 | 22 | A1 |
| GPIO 4 | 23 | A2 |
| GPIO 16 | 24 | A3 |
| GPIO 17 | 25 | A4 |
| GPIO 5 | 26 | A5 |
| GPIO 18 | 27 | A6 |
| GPIO 19 | 28 | A7 |
| GPIO 21 | — | A8 (directly to ROM via bus extension) |
| GPIO 22 | — | A9 |
| GPIO 23 | — | A10 |
| GPIO 34* | — | A11 |
| GPIO 35* | — | A12 |
| GPIO 36* | — | A13 |
| GPIO 39* | — | A14 |

*GPIO 34-39 are input-only on ESP32. Need alternative for A11-A14.

**Revised approach**: Use shift register (74HC595) for high address bits:

```
ESP32 (3 pins: DATA, CLK, LATCH) → 74HC595 → A8-A14 (7 bits)
```

This uses only 3 ESP32 pins for the upper 7 address bits. Total GPIO: 8 (data) + 8 (addr low) + 3 (shift reg) + 3 (control) = **22 GPIO**. Fits easily.

### Control Signals

| ESP32 GPIO | Bus Pin | Signal | Direction |
|:----------:|:-------:|--------|:---------:|
| GPIO 0 | 6 | /RST | output |
| GPIO 2 | 7 | /RD | output |
| GPIO 4 | 8 | /WR | output |
| — | 11 | /SLOT1 | input (RUN mode, detect slot access) |

### Shift Register for A[8:14] (1× 74HC595 on programmer board)

| ESP32 GPIO | 74HC595 Pin | Function |
|:----------:|:-----------:|----------|
| GPIO 23 | 14 (SER) | Serial data |
| GPIO 18 | 11 (SRCLK) | Shift clock |
| GPIO 5 | 12 (RCLK) | Latch output |

74HC595 Q0-Q6 → ROM A8-A14 (directly, or via bus if RV8 has full address on bus)

**Note**: For RV8/RV801 (which have A[15:0] on the 40-pin bus), the shift register is NOT needed — ESP32 drives all address lines directly via the bus. The shift register is only needed for RV808 ROM programming header.

---

## Simplified Pin Map (RV8/RV801 — full address on bus)

| Function | ESP32 GPIOs | Count |
|----------|:-----------:|:-----:|
| D[7:0] | 32,33,25,26,27,14,12,13 | 8 |
| A[7:0] | 15,2,4,16,17,5,18,19 | 8 |
| A[8:14] | 21,22,23,34,35,36,39 | 7* |
| /RST | 0 | 1 |
| /RD | — (directly from bus, optional) | 0 |
| /WR | — (use GPIO for ROM /WE) | 1 |
| /SLOT1 (RUN mode) | input pin | 1 |
| **Total** | | **~20** |

*A[8:14] only needed in PROG mode. In RUN mode these pins are tri-stated/unused.

---

## PROG Mode — ROM Flash Sequence

```
1. Switch to PROG → ESP32 pulls /RST low
2. PC sends: "FLASH <size>\n" over USB-serial
3. ESP32 receives .bin data
4. For each byte:
   a. Set A[14:0] (address)
   b. Set D[7:0] (data)
   c. /CE=LOW, /OE=HIGH
   d. Pulse /WE LOW for 200ns
   e. Wait for write completion (poll D7 or 10ms delay)
5. Verify: read back all bytes, compare
6. ESP32 sends "OK\n" to PC
7. Switch to RUN → ESP32 releases /RST → CPU boots
```

---

## RUN Mode — UART Terminal Bridge

```
CPU writes to I/O slot:
  PAGE $F0          ; system I/O page
  SB pg:$00         ; write byte → ESP32 sees /SLOT active + data on D[7:0]
  
ESP32 detects:
  /SLOT1 goes LOW + /WR goes LOW → latch D[7:0] → send over USB to PC

PC sends keystroke:
  ESP32 receives byte over USB
  ESP32 waits for CPU to read:
    CPU does: LB pg:$00 → ESP32 drives D[7:0] with received byte

Flow:
  PC terminal ←USB→ ESP32 ←slot I/O→ CPU
```

### I/O Register Map (at slot page $F0):

| Offset | R/W | Function |
|:------:|:---:|----------|
| $00 | R | RX data (read byte from PC) |
| $00 | W | TX data (send byte to PC) |
| $01 | R | Status: bit0=rx_ready, bit1=tx_busy |

---

## RV808 Note

RV808 ROM is wired directly to PC (internal, not on bus). For ROM programming:
- **Option A**: Add 6-pin ROM header on RV808 CPU board (A8-A14 exposed)
- **Option B**: Program ROM off-board with TL866 before inserting
- **Terminal mode works fine** — uses slot on the 40-pin bus, same as RV8

---

## Voltage Level Shifting (CRITICAL)

ESP32 is **3.3V**. The RV8-Bus is **5V** (74HC logic). Direct connection will damage the ESP32.

**Solution**: TXB0108 bidirectional level shifter modules (8-channel, ~$1 each):

```
ESP32 (3.3V) ←→ [TXB0108 ×3] ←→ 40-pin bus (5V)
                 level shifters
```

| Module | Channels | Signals |
|:------:|:--------:|---------|
| TXB0108 #1 | 8 | D[7:0] — bidirectional |
| TXB0108 #2 | 8 | A[7:0] — output (PROG mode) |
| TXB0108 #3 | 4+ | /RST, /WR, /RD, /SLOT1, SYNC |

Wire: TXB0108 VA = 3.3V (ESP32 side), VB = 5V (bus side), GND shared.

---

## Parts List

| Part | Qty | Cost |
|------|:---:|:----:|
| ESP32 NodeMCU (30-pin) | 1 | ~$4 |
| TXB0108 level shifter module (8-ch) | 3 | ~$3 |
| 40-pin IDC connector + ribbon | 1 | ~$2 |
| SPDT toggle switch (PROG/RUN) | 1 | ~$0.50 |
| 74HC595 (shift register, for A8-A14) | 1 | ~$0.30 |
| **Total** | | **~$10** |

---

## PC Software

### Workflow (assemble → flash → run → interact)

```bash
# 1. Write your program
vim hello.asm

# 2. Assemble to binary
python3 RV8/tools/rv8asm.py hello.asm -f bin -o hello.bin

# 3. Flip switch to PROG → flash ROM
python3 Programmer/tools/rv8flash.py /dev/ttyUSB0 hello.bin
# Output: "Flashing 128 bytes... OK"

# 4. Flip switch to RUN → CPU boots, open terminal
python3 Programmer/tools/rv8term.py /dev/ttyUSB0
# Output: "Hello World!"
# Type to send input to CPU. Ctrl+C to exit.
```

### Commands

```bash
# Flash ROM
python3 Programmer/tools/rv8flash.py /dev/ttyUSB0 program.bin

# Terminal mode (or just use: screen /dev/ttyUSB0 115200)
python3 Programmer/tools/rv8term.py /dev/ttyUSB0
```

---

## Compatibility

| CPU Board | PROG (flash ROM) | RUN (terminal) |
|-----------|:-:|:-:|
| RV8 (26 chips) | ✅ Full address on bus | ✅ Via slot |
| RV801 (8-9 chips) | ✅ Same bus as RV8 | ✅ Via slot |
| RV808 (23 chips) | ⚠️ Need ROM header or off-board | ✅ Via slot |

---

## Thai Version

ส่วนนี้เขียนเป็นภาษาไทยสำหรับน้อง ๆ ม.ต้น ที่อยากสร้างบอร์ด Programmer ให้ CPU RV8

---

### 1. เป้าหมาย

บอร์ด Programmer ทำหน้าที่ 2 อย่าง:

1. **โหมด PROG** — เขียนโปรแกรมลง ROM (เหมือนก๊อปไฟล์ลง USB แต่เป็นชิป)
2. **โหมด RUN** — เป็น "หน้าจอ" ให้ CPU คุยกับคอมพิวเตอร์ผ่านสาย USB (พิมพ์ตัวอักษรไป-กลับ)

สลับโหมดด้วยสวิตช์ตัวเดียว ง่ายมาก!

---

### 2. อุปกรณ์

| ชิ้น | ชื่อ | หน้าที่ | จำนวน | ราคาประมาณ |
|:----:|------|---------|:-----:|:----------:|
| 1 | ESP32 NodeMCU (30 ขา) | สมองของบอร์ด — ต่อ USB กับคอม, ควบคุมทุกอย่าง | 1 | ~฿140 |
| 2 | TXB0108 (โมดูล 8 ช่อง) | แปลงไฟ 3.3V↔5V ให้ ESP32 คุยกับ CPU ได้ | 3 | ~฿105 |
| 3 | 74HC595 (shift register) | ส่ง address สูง A8-A14 ไปหา ROM (ใช้สายแค่ 3 เส้น) | 1 | ~฿10 |
| 4 | สาย IDC 40 พิน + หัวต่อ | เชื่อมบอร์ด Programmer กับบอร์ด CPU | 1 | ~฿70 |
| 5 | สวิตช์ SPDT (3 ขา) | เลือก PROG หรือ RUN | 1 | ~฿15 |
| 6 | ตัวต้านทาน 10kΩ | pull-up สำหรับ GPIO 0 (ป้องกัน boot ผิดโหมด) | 1 | ~฿1 |
| 7 | ตัวเก็บประจุ 100nF | กรองไฟให้ TXB0108 (ติดข้าง ๆ ขา VCC) | 6 | ~฿6 |

**รวม ~฿350** (ไม่รวมบอร์ด CPU)

---

### 3. ขั้นตอนต่อวงจร

ต่อทีละส่วน ทดสอบแต่ละขั้นก่อนไปขั้นถัดไป

#### ขั้นที่ 1 — จ่ายไฟ

| จาก | ไป | หมายเหตุ |
|------|-----|----------|
| ESP32 VIN (5V จาก USB) | Bus pin 39 (VCC) | จ่ายไฟ 5V ให้บอร์ด CPU |
| ESP32 3.3V | TXB0108 ทุกตัว ขา VCCA | ฝั่งแรงดันต่ำ |
| Bus pin 39 (5V) | TXB0108 ทุกตัว ขา VCCB | ฝั่งแรงดันสูง |
| ESP32 3.3V | 74HC595 ขา 16 (VCC) | จ่ายไฟ shift register |
| ESP32 GND | Bus pin 40 (GND) | กราวด์ร่วม |
| TXB0108 ขา OE | ต่อเข้า VCCA (3.3V) | เปิดใช้งานตลอด |

> ⚡ ติด C 100nF ข้างขา VCCA และ VCCB ของ TXB0108 ทุกตัว (6 ตัว)

#### ขั้นที่ 2 — Data Bus (D0-D7)

| ESP32 GPIO | → TXB0108 #1 ช่อง | → Bus Pin | สัญญาณ |
|:----------:|:-----------------:|:---------:|--------|
| 32 | A1/B1 | 17 | D0 |
| 33 | A2/B2 | 18 | D1 |
| 25 | A3/B3 | 19 | D2 |
| 26 | A4/B4 | 20 | D3 |
| 27 | A5/B5 | 21 | D4 |
| 14 | A6/B6 | 22 | D5 |
| 12 | A7/B7 | 23 | D6 |
| 13 | A8/B8 | 24 | D7 |

#### ขั้นที่ 3 — Address Bus ต่ำ (A0-A7)

| ESP32 GPIO | → TXB0108 #2 ช่อง | → Bus Pin | สัญญาณ |
|:----------:|:-----------------:|:---------:|--------|
| 15 | A1/B1 | 1 | A0 |
| 2 | A2/B2 | 2 | A1 |
| 4 | A3/B3 | 3 | A2 |
| 16 | A4/B4 | 4 | A3 |
| 17 | A5/B5 | 5 | A4 |
| 5 | A6/B6 | 6 | A5 |
| 18 | A7/B7 | 7 | A6 |
| 19 | A8/B8 | 8 | A7 |

#### ขั้นที่ 4 — Shift Register (74HC595) สำหรับ A8-A14

| 74HC595 ขา | ต่อไปที่ | หมายเหตุ |
|:-----------:|----------|----------|
| 14 (SER) | ESP32 GPIO 23 | ข้อมูลเข้า |
| 11 (SRCLK) | ESP32 GPIO 18 | นาฬิกาเลื่อนบิต |
| 12 (RCLK) | ESP32 GPIO 5 | สั่งให้ output ออก |
| 10 (/SRCLR) | ต่อเข้า 3.3V | ไม่ clear (ค้างไว้) |
| 13 (/OE) | ต่อเข้า GND | เปิด output ตลอด |
| 16 (VCC) | 3.3V | ไฟเลี้ยง |
| 8 (GND) | GND | กราวด์ |
| 15 (Q0) | TXB0108 #3 A1 → Bus pin 9 | A8 |
| 1 (Q1) | TXB0108 #3 A2 → Bus pin 10 | A9 |
| 2 (Q2) | TXB0108 #3 A3 → Bus pin 11 | A10 |
| 3 (Q3) | TXB0108 #3 A4 → Bus pin 12 | A11 |
| 4 (Q4) | TXB0108 #3 A5 → Bus pin 13 | A12 |
| 5 (Q5) | TXB0108 #3 A6 → Bus pin 14 | A13 |
| 6 (Q6) | TXB0108 #3 A7 → Bus pin 15 | A14 |

#### ขั้นที่ 5 — สัญญาณควบคุม

| จาก | ไป | หน้าที่ |
|------|-----|---------|
| ESP32 GPIO 0 | TXB0108 #3 A8/B8 → Bus pin 28 | /RST (รีเซ็ต CPU) |
| ESP32 GPIO 21 | สายตรงไปขา /WE ของ ROM | เขียน ROM (PROG mode) |

#### ขั้นที่ 6 — สวิตช์ PROG/RUN

| ขาสวิตช์ | ต่อไปที่ | หมายเหตุ |
|:---------:|----------|----------|
| ขากลาง (COM) | ESP32 GPIO 0 | อ่านค่าสวิตช์ |
| ขาซ้าย (PROG) | GND | กด PROG = LOW = CPU หยุด |
| ขาขวา (RUN) | 3.3V | กด RUN = HIGH = CPU ทำงาน |

> 💡 ต่อตัวต้านทาน 10kΩ จาก GPIO 0 ไป 3.3V (pull-up) เพื่อให้ ESP32 บูตได้ปกติ

---

### 4. วิธีใช้

#### โหมด PROG — เขียนโปรแกรมลง ROM

1. เลื่อนสวิตช์ไปตำแหน่ง **PROG**
2. ต่อสาย USB จากคอมเข้า ESP32
3. เปิด Terminal แล้วพิมพ์:
   ```
   python3 rv8flash.py /dev/ttyUSB0 program.bin
   ```
4. รอจนขึ้น progress bar เต็ม ✅
5. เลื่อนสวิตช์ไป **RUN** — CPU จะเริ่มทำงานทันที

#### โหมด RUN — เป็นหน้าจอ Terminal

1. เลื่อนสวิตช์ไปตำแหน่ง **RUN**
2. เปิด Terminal แล้วพิมพ์:
   ```
   python3 rv8term.py /dev/ttyUSB0
   ```
3. ตอนนี้คุณพิมพ์อะไร CPU จะได้รับ, CPU ส่งอะไรมาจะขึ้นจอ
4. กด **Ctrl+C** เพื่อออก

#### สรุปง่าย ๆ

| ทำอะไร | สวิตช์ | คำสั่ง |
|--------|:------:|--------|
| เขียน ROM | PROG | `python3 rv8flash.py <port> <file>` |
| คุยกับ CPU | RUN | `python3 rv8term.py <port>` |

---

### 5. ทดสอบ

ทำตามลำดับ ✅ ทุกข้อก่อนไปข้อถัดไป:

| # | ทดสอบ | วิธีเช็ค | ผ่าน? |
|:-:|--------|----------|:-----:|
| 1 | ไฟเข้า ESP32 | ต่อ USB → ไฟ LED บน ESP32 ติด | ☐ |
| 2 | ไฟ 5V ถึง Bus | วัดไฟ Bus pin 39-40 ได้ ~5V | ☐ |
| 3 | ไฟ 3.3V ถึง TXB0108 | วัดขา VCCA ได้ ~3.3V ทุกตัว | ☐ |
| 4 | สวิตช์ทำงาน | PROG → วัด GPIO 0 ได้ 0V, RUN → ได้ 3.3V | ☐ |
| 5 | /RST ถึง Bus | PROG → วัด Bus pin 28 ได้ ~0V, RUN → ได้ ~5V | ☐ |
| 6 | Flash ROM | รัน rv8flash.py → ขึ้น "Done" ไม่มี error | ☐ |
| 7 | Verify ROM | ถอด ROM ไปอ่านด้วย TL866 → ข้อมูลตรง | ☐ |
| 8 | CPU บูต | สวิตช์ RUN → CPU เริ่มทำงาน (ดูจาก LED หรือ terminal) | ☐ |
| 9 | Terminal ส่งได้ | พิมพ์ใน rv8term → CPU ได้รับ (echo กลับมา) | ☐ |
| 10 | Terminal รับได้ | CPU ส่งข้อความ → ขึ้นจอใน rv8term | ☐ |

> 🎉 ถ้าผ่านครบ 10 ข้อ = บอร์ด Programmer ใช้งานได้สมบูรณ์!

---

*เขียนสำหรับน้อง ๆ ม.ต้น — ถ้าติดตรงไหนถามพี่ได้เลย!*