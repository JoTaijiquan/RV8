# Lab 1: Clock and Reset Circuit

## Objective
Build a free-running clock source and clean reset signal for the RV8 CPU.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 3.5 MHz crystal oscillator | 1 | Full-can oscillator module (4-pin) |
| Tactile pushbutton | 1 | RESET |
| 10KΩ resistor | 1 | Pull-up for /RST |
| 100nF capacitor | 2 | Debounce + decoupling |
| LED + 330Ω | 2 | CLK indicator, /RST indicator |

## Schematic

```
  3.5MHz OSC module
  ┌─────────┐
  │ VCC  OUT├──────────────► CLK rail
  │         │                  │
  │ GND  NC │              LED + 330Ω → GND
  └─────────┘

  /RST circuit:
  VCC ─── 10K ─┬─── /RST output → all /CLR pins
               │
  RESET btn ───┘
  (to GND)     │
              100nF ─── GND
```

## Simulate First

```bash
cd sim/
iverilog -o lab1 lab1_clock_tb.v && vvp lab1
gtkwave lab1.vcd
```

**What to check in GTKWave:**
- `osc`: continuous 3.5 MHz square wave
- `rst_n`: goes LOW on reset, returns HIGH cleanly

---

## Procedure

1. Wire crystal oscillator: VCC to +5V, GND to GND, OUT to CLK rail.
2. Add 100nF decoupling cap between VCC and GND near the oscillator.
3. Connect CLK LED + 330Ω from CLK rail to GND (visual indicator).
4. Build /RST circuit: 10K pull-up to VCC, button to GND, 100nF cap for debounce.
5. Connect /RST LED + 330Ω (lights when reset is active LOW).

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | Power on | CLK LED appears solid (too fast to see blink) |
| 2 | Probe CLK with scope | Clean 3.5 MHz square wave, ~50% duty |
| 3 | Press RESET | /RST LED lights, /RST line goes LOW |
| 4 | Release RESET | /RST returns HIGH cleanly (no bounce) |

## Checkoff

- [ ] CLK output: 3.5 MHz square wave (verify with scope or frequency counter)
- [ ] /RST: clean LOW when pressed, HIGH when released
- [ ] No ringing or bounce on /RST (verify with scope)

## Notes
- The CLK LED won't visibly blink at 3.5 MHz — it will appear always-on. This is normal.
- Single-step debugging is provided by the Trainer board (not on the CPU board).
- Keep wires from the oscillator short to avoid noise.
- The 4-pin oscillator module has: VCC, GND, OUT, NC (no connect).

---

# Thai Version

---

# แลป 1: วงจร Clock และ Reset

---

## เป้าหมาย

สร้าง "หัวใจ" ของคอมพิวเตอร์ — สัญญาณ Clock ที่วิ่งตลอดเวลา และปุ่ม Reset

---

## ความรู้พื้นฐาน

**Clock (CLK)** = จังหวะการทำงาน ทุกครั้งที่ CLK กระพริบ 1 ครั้ง CPU ทำงาน 1 ขั้นตอน

**Reset (/RST)** = ปุ่มเริ่มใหม่ กดแล้ว CPU กลับไปเริ่มต้น

Clock บน CPU board วิ่งเองตลอด 3.5 ล้านครั้ง/วินาที (breadboard) หรือ 10 ล้านครั้ง/วินาที (PCB)

**Single-step** อยู่บน Trainer board — ไม่ได้อยู่บน CPU board

---

## อุปกรณ์

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| Crystal Oscillator 3.5 MHz (4 ขา) | 1 | สร้างจังหวะ Clock |
| ปุ่มกด | 1 | RESET |
| ตัวต้านทาน 10KΩ | 1 | ดึงสัญญาณ /RST ให้เป็น HIGH |
| ตัวเก็บประจุ 100nF | 2 | กันปุ่มเด้ง + decoupling |
| LED + ตัวต้านทาน 330Ω | 2 | ไฟแสดงสถานะ CLK และ /RST |

---

## ผังวงจร

```
  Crystal Oscillator (กล่องเหล็ก 4 ขา)
  ┌─────────┐
  │ VCC  OUT├──────► CLK rail ──► LED ──[330Ω]──► GND
  │         │
  │ GND  NC │
  └─────────┘
  (ต่อ 100nF ระหว่าง VCC กับ GND ใกล้ตัว oscillator)


  วงจร Reset:

  +5V ──[10K]──┬──► /RST ──► LED ──[330Ω]──► GND
               │
  ปุ่ม RESET──┘
  (ต่อลง GND) │
              100nF
               │
              GND
```

---

## ขั้นตอนต่อวงจร

1. ต่อ Crystal Oscillator: VCC → +5V, GND → GND, OUT → CLK rail
2. ต่อ 100nF ระหว่าง VCC กับ GND ใกล้ตัว oscillator (decoupling)
3. ต่อ LED + 330Ω จาก CLK rail ลง GND
4. สร้างวงจร Reset: 10K pull-up + ปุ่มลง GND + 100nF กัน bounce
5. ต่อ LED + 330Ω ที่ /RST

---

## ทดสอบ

| ขั้น | ทำอะไร | ผลที่ถูกต้อง |
|:----:|--------|-------------|
| 1 | เปิดไฟ | LED CLK ติดค้าง (เร็วเกินจะเห็นกระพริบ) |
| 2 | วัด CLK ด้วย scope | คลื่นสี่เหลี่ยม 3.5 MHz สะอาด |
| 3 | กดปุ่ม RESET | LED RST ติด, สาย /RST = 0V |
| 4 | ปล่อยปุ่ม RESET | LED RST ดับ, สาย /RST = 5V สะอาด |

---

## เช็คลิสต์ผ่าน

- [ ] CLK: คลื่นสี่เหลี่ยม 3.5 MHz (วัดด้วย scope)
- [ ] กด RESET: /RST เป็น LOW
- [ ] ปล่อย RESET: /RST กลับเป็น HIGH สะอาด (ไม่เด้ง)

---

## หมายเหตุ

- LED ที่ต่อกับ Clock จะดูเหมือนติดตลอด — เป็นเรื่องปกติ เพราะกระพริบ 3.5 ล้านครั้ง/วินาที
- ถ้าต้องการ single-step ให้ต่อ Trainer board (จะมีปุ่ม STEP + LED แสดงสถานะ)
- ต่อสายจาก Oscillator ให้สั้นที่สุด เพื่อลดสัญญาณรบกวน
- Oscillator 4 ขา: VCC, GND, OUT, NC (ขาที่ 4 ไม่ต้องต่อ)
