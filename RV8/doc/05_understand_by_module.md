# RV8 — Understand by Module (How Chips Become a CPU)

**27 normal chips. Connected by wires. Becomes a computer. Here's how.**

---

## The Big Question: How do simple chips become a CPU?

A 74HC574 is just a box that remembers 8 bits. A 74HC283 just adds two numbers. A 74HC138 just picks one of 8 outputs. None of them is a "CPU chip."

But connect them with wires in the right way → they work together → **that IS a CPU.**

This document explains WHY each chip is there and WHAT it does in the system.

---

## Module 1: Registers (U1-U8) — "8 boxes that remember"

### Chips: 8× 74HC574 (Octal D Flip-Flop with /OE)

### Why this chip?
74HC574 does exactly what a register needs:
- **8 D inputs**: receive new data (from ALU result)
- **8 Q outputs**: send stored data (to IBUS when selected)
- **CLK pin**: rising edge = "remember NOW" (write)
- **/OE pin**: LOW = outputs active, HIGH = outputs disconnected (tri-state)

### Why 8 of them?
Each 574 holds one 8-bit number. We need 8 registers (r0-r7) = 8 chips.

### How they become registers:
```
U20 (138 decoder) picks which register's /OE goes LOW → that register talks on IBUS
U21 (138 decoder) picks which register's CLK pulses → that register saves new data
All other registers stay quiet (/OE=HIGH, CLK=no pulse)
```

### Why /OE matters:
Without /OE, all 8 registers would drive IBUS simultaneously → **short circuit!**
With /OE, only ONE register talks at a time. The others disconnect. Safe.

---

## Module 2: ALU (U12-U15, U25) — "the calculator"

### Chips:
- 2× 74HC283 (4-bit adder) = U12 + U13
- 2× 74HC86 (quad XOR) = U14 + U15
- 1× 74HC574 (result latch) = U25

### Why 74HC283?
It adds two 4-bit numbers with carry. Two of them chained = 8-bit adder.
```
U12: adds bits 0-3 (low nibble), carry out → U13 carry in
U13: adds bits 4-7 (high nibble), carry out → flag_c
```

### Why 74HC86 (XOR)?
**To make subtraction from addition.** Math trick: `A - B = A + (NOT B) + 1`

XOR with 0 = pass through (for ADD): `B XOR 0 = B`
XOR with 1 = invert (for SUB): `B XOR 1 = NOT B`

So: one control signal (ALU_SUB) flips all XOR gates → adder does subtraction!

### Why U25 (result latch)?
ALU output is **combinational** (changes instantly when inputs change). We need to **capture** the result at the right moment. U25 (574) latches it on ALUR_CLK pulse.

### How they become a calculator:
```
IBUS → XOR (U14+U15) → Adder (U12+U13) → Result latch (U25) → ALU_R bus → registers
         ↑                                                              
    ALU_SUB signal (0=add, 1=subtract)
```

---

## Module 3: PC (U16-U17) — "the bookmark"

### Chips: 2× 74HC574 (with /OE)

### Why 574 (not 74HC161 counter)?
We NEED /OE! During data access, PC must **disconnect** from address bus so address latches can drive instead. 74HC161 has no /OE — can't disconnect.

PC increment is done by ALU (microcode computes PC+1). Costs 1 extra step but saves the bus conflict problem.

### How it becomes a program counter:
```
Normal: PC drives address bus (/OE=LOW) → ROM sends instruction
Branch: ALU computes new address → PC latches it (CLK pulse)
Data access: PC disconnects (/OE=HIGH) → address latches take over
```

---

## Module 4: Address Latches (U18-U19) — "the address holder"

### Chips: 2× 74HC574 (with /OE)

### Why needed?
For memory access (LB/SB), we need a register's value on the address bus. But registers are on IBUS, not address bus. Solution: **copy** the value from IBUS into address latches, then latches drive address bus.

### How they work:
```
Step 1: Register drives IBUS → address latch captures (CLK pulse)
Step 2: PC disconnects (/OE=HIGH), address latch connects (/OE=LOW)
Step 3: Address latch drives ROM/RAM address pins → memory access happens
Step 4: Done, PC reconnects, latches disconnect
```

### Why /OE on both PC and latches?
**Only one can drive address bus at a time.** Microcode signal `PC_ADDR` controls:
- PC_ADDR=1: PC drives (fetch mode)
- PC_ADDR=0: Latches drive (data access mode)

---

## Module 5: Bus Buffer (U22) — "the bridge"

### Chip: 1× 74HC245 (Octal Bus Transceiver)

### Why needed?
IBUS (internal) and RV8-Bus D[7:0] (external, to ROM/RAM) are **separate buses**. U22 connects them when needed, disconnects when not.

### Why 74HC245?
- **Bidirectional**: can go A→B (write to RAM) or B→A (read from ROM)
- **/OE pin**: can disconnect completely (during ALU operations, no memory access)
- **DIR pin**: controls direction

### How it becomes a bridge:
```
Read from ROM:  DIR=0 (B→A), /OE=LOW → ROM data appears on IBUS
Write to RAM:   DIR=1 (A→B), /OE=LOW → IBUS data goes to RAM
ALU operation:  /OE=HIGH → bridge disconnected, IBUS free for registers
```

---

## Module 6: Control (U20-U21, U23, U24, U26, U27) — "the brain"

### Chips:
- 2× 74HC138 (3-to-8 decoder) = U20 (read select) + U21 (write select)
- 2× SST39SF010A (Flash ROM) = U23 + U27 (microcode)
- 1× 74HC74 (dual flip-flop) = U24 (flags Z, C)
- 1× 74HC161 (4-bit counter) = U26 (step counter)

### Why 74HC138 (U20, U21)?
Need to select 1 of 8 registers. 3 input bits → 8 output lines. Perfect for:
- U20: "which register READS onto IBUS" (controls /OE pins)
- U21: "which register WRITES from ALU result" (controls CLK pins)

### Why Flash ROM (U23 + U27)?
The microcode table. Every combination of {step, opcode, flags} → 16 control signals.
One Flash chip = 8 output bits. Need 16 bits → use 2 Flash chips (same address, different outputs).

**This is the "brain" — it knows what to do for every instruction at every step.**

### Why 74HC74 (U24)?
Stores flags: Z (zero) and C (carry). These feed back into Flash address → microcode can make different decisions based on flags (for branches).

### Why 74HC161 (U26)?
Step counter. Counts 0,1,2,3,4,5,6,7,0,1,... Each step = one micro-operation. Resets to 0 at end of instruction (STEP_RST signal from microcode).

### How they become a brain:
```
Every clock cycle:
  U26 (step) + U9 (opcode) + U24 (flags) → Flash address
  Flash outputs 16 bits → directly control everything:
    "register 3 read!" "ALU subtract!" "latch result!" "next step!"
```

---

## How ALL modules connect:

```
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  U1-U8 (574×8)     U12-U13 (283×2)    U16-U17 (574×2)     │
│  [Registers]        [Adder]             [PC]                │
│       ↕                ↓                   ↕                │
│  ═══ IBUS (internal 8-bit bus) ═══    ═══ ADDRESS BUS ═══   │
│       ↕                                    ↕                │
│  U22 (245)                            U18-U19 (574×2)       │
│  [Bridge]                             [Addr Latches]        │
│       ↕                                                     │
│  ═══ RV8-Bus D[7:0] (external) ═══════════════════════════  │
│       ↕                                                     │
│  ROM + RAM (on RV8-Bus)                                     │
│                                                              │
│  U23+U27 (Flash×2) + U26 (161) + U24 (74) + U20+U21 (138×2)│
│  [CONTROL — reads opcode+step+flags, outputs all signals]   │
└─────────────────────────────────────────────────────────────┘
```

---

## Why THESE chips? (Summary)

| Chip | Why this one? | What makes it special? |
|------|--------------|----------------------|
| 74HC574 | Register | Has /OE (tri-state) + CLK (edge-triggered) |
| 74HC283 | Adder | 4-bit add with carry chain |
| 74HC86 | XOR | Turns adder into subtractor |
| 74HC138 | Decoder | 3 bits → select 1 of 8 (register pick) |
| 74HC245 | Bus bridge | Bidirectional + /OE (connect/disconnect) |
| 74HC161 | Counter | Auto-counts (step sequencer) |
| 74HC74 | Flip-flop | Remembers 1 bit (flags) |
| SST39SF010A | Flash ROM | Big lookup table (microcode brain) |

**None of these chips is "smart." They just do ONE simple thing. But connected together with the right wires → they execute programs. That's what a CPU is.**

---
---

# ภาษาไทย — ทำไมชิปธรรมดาถึงกลายเป็น CPU ได้

---

## CPU คืออะไร?

CPU ไม่ใช่ชิปพิเศษ มันคือ **ชิปธรรมดาหลายตัวต่อสายเข้าด้วยกัน**

ชิปแต่ละตัวทำได้แค่อย่างเดียว:
- 74HC574 = **จำเลข** (8 บิต)
- 74HC283 = **บวกเลข** (4 บิต)
- 74HC86 = **กลับบิต** (XOR)
- 74HC138 = **เลือก 1 จาก 8**
- 74HC245 = **สะพานเชื่อม** (2 ทิศทาง)

แต่ต่อสายถูกวิธี → ทำงานร่วมกัน → **= CPU!**

---

## ส่วนที่ 1: กล่องเก็บเลข (U1-U8)

**ชิป: 74HC574 × 8 ตัว**

### ทำไมต้อง 574?
เพราะมันมี:
- ขา D (8 ขา): รับเลขใหม่
- ขา Q (8 ขา): ส่งเลขที่จำไว้ออกมา
- ขา CLK: พอกดปุ๊บ = จำเลขใหม่ทันที
- ขา /OE: ปิด=ส่งเลขออก, เปิด=ตัดการเชื่อมต่อ (เงียบ)

### ทำไมต้อง 8 ตัว?
ต้องการ 8 กล่อง (r0-r7) กล่องละ 1 ชิป = 8 ชิป

### ทำไมต้องมี /OE?
ถ้าไม่มี → กล่อง 8 ใบพูดพร้อมกัน → **ลัดวงจร! ไหม้!**
มี /OE → เปิดทีละใบ → ปลอดภัย ✅

---

## ส่วนที่ 2: เครื่องบวกเลข (U12-U15)

**ชิป: 74HC283 × 2 + 74HC86 × 2**

### ทำไมต้อง 283?
มันบวกเลข 4 บิตได้ ต่อ 2 ตัว = บวก 8 บิต (0-255)
```
U12: บวกหลักหน่วย (บิต 0-3)
U13: บวกหลักสิบ (บิต 4-7) + รับทดจาก U12
```

### ทำไมต้อง 86 (XOR)?
**เคล็ดลับ: ทำให้เครื่องบวก ลบได้ด้วย!**

```
บวก: B ผ่าน XOR กับ 0 = B เหมือนเดิม → A + B
ลบ:  B ผ่าน XOR กับ 1 = กลับบิต B → A + (NOT B) + 1 = A - B
```

สัญญาณ 1 เส้น (ALU_SUB) เปลี่ยนจากบวกเป็นลบ!

---

## ส่วนที่ 3: ตัวชี้ตำแหน่ง (U16-U17)

**ชิป: 74HC574 × 2 (PC low + PC high)**

### ทำไมต้อง 574 (ไม่ใช่ 161 ตัวนับ)?
เพราะ 574 มี /OE! ตอนอ่าน RAM ต้อง **ถอด PC ออกจากสาย address** ให้ตัวอื่นขับแทน 161 ถอดไม่ได้ (ไม่มี /OE)

### มันทำอะไร?
- ปกติ: PC ส่งตำแหน่งไป ROM → ROM ส่งคำสั่งกลับมา
- ตอนอ่าน RAM: PC ถอดตัวเอง → address latch ขับแทน

---

## ส่วนที่ 4: ตัวจำที่อยู่ (U18-U19)

**ชิป: 74HC574 × 2**

### ทำไมต้องมี?
ตอนอ่าน/เขียน RAM ต้องบอก "ที่อยู่" ให้ RAM ค่าที่อยู่มาจาก register (อยู่บน IBUS) แต่ RAM ต้องการบนสาย address

**วิธี**: คัดลอกค่าจาก IBUS → ใส่ address latch → latch ขับสาย address

---

## ส่วนที่ 5: สะพานเชื่อม (U22)

**ชิป: 74HC245 × 1**

### ทำไมต้องมี?
IBUS (ภายใน) กับ สาย D[7:0] ของ ROM/RAM (ภายนอก) เป็น **คนละสาย**
U22 เชื่อมเมื่อต้องการ ตัดเมื่อไม่ต้องการ

```
อ่าน ROM: เปิดสะพาน ทิศ ROM→IBUS
เขียน RAM: เปิดสะพาน ทิศ IBUS→RAM
คำนวณ ALU: ปิดสะพาน (ไม่ยุ่งกับ memory)
```

---

## ส่วนที่ 6: สมอง (U20-U27)

**ชิป: 74HC138×2 + Flash×2 + 74HC74 + 74HC161**

### U20 + U21 (74HC138): ตัวเลือก
- U20: เลือกว่า "กล่องไหนพูด" (ขับ IBUS)
- U21: เลือกว่า "กล่องไหนจำ" (รับค่าใหม่)

### U23 + U27 (Flash): ตารางคำสั่ง
**หัวใจของ CPU!** เป็นตารางขนาดใหญ่:
```
ถ้า step=0 และ opcode=ADDI → สั่ง: "เปิดสะพาน อ่าน ROM จำ opcode"
ถ้า step=2 และ opcode=ADDI → สั่ง: "จำ operand เข้า ALU B"
ถ้า step=3 และ opcode=ADDI → สั่ง: "ALU บวก จำผลลัพธ์"
```

### U24 (74HC74): ธง (flags)
จำว่า "ผลลัพธ์ล่าสุดเป็น 0 ไหม?" (Z) และ "ล้นไหม?" (C)
ใช้ตัดสินใจตอน branch (กระโดดหรือไม่กระโดด)

### U26 (74HC161): ตัวนับขั้นตอน
นับ 0,1,2,3,4,5... แล้ว reset กลับ 0 เมื่อจบคำสั่ง
บอก Flash ว่า "ตอนนี้อยู่ขั้นตอนไหน"

---

## ทำไมชิปธรรมดาถึงกลายเป็น CPU?

| ชิป | ทำอะไรได้เอง | ทำอะไรใน CPU |
|-----|:----------:|:----------:|
| 574 | จำเลข 8 บิต | เป็น register, PC, address latch, IR |
| 283 | บวกเลข 4 บิต | เป็น ALU (ต่อ 2 ตัว = 8 บิต) |
| 86 | กลับบิต (XOR) | ทำให้บวกกลายเป็นลบ |
| 138 | เลือก 1 จาก 8 | เลือก register ที่จะอ่าน/เขียน |
| 245 | สะพาน 2 ทาง | เชื่อม CPU กับ ROM/RAM |
| 161 | นับเลข | นับขั้นตอน (step counter) |
| 74 | จำ 1 บิต | จำ flag (ผลลัพธ์เป็น 0?) |
| Flash | ตารางค้นหา | สมอง (microcode) |

**ชิปแต่ละตัวโง่มาก ทำได้แค่อย่างเดียว**
**แต่ต่อสายถูก → ทำงานร่วมกัน → รันโปรแกรมได้ → นั่นคือ CPU!** 🎉
