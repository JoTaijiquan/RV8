# RV8 — Understand by Module

**Break the CPU into 6 simple modules. Build and test each one separately.**

---

## The Big Picture

```
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐           │
│  │ Module 1 │   │ Module 2 │   │ Module 3 │           │
│  │ REGISTER │   │   ALU    │   │    PC    │           │
│  │   FILE   │   │  (math)  │   │(counter) │           │
│  │ 8 boxes  │   │  adder   │   │ address  │           │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘           │
│       │               │               │                 │
│       ▼               ▼               ▼                 │
│  ═══════════════ INTERNAL BUS (IBUS) ═══════════════    │
│       ▲               ▲               ▲                 │
│       │               │               │                 │
│  ┌────┴─────┐   ┌────┴─────┐   ┌────┴─────┐          │
│  │ Module 4 │   │ Module 5 │   │ Module 6 │          │
│  │INSTRUCTION│   │ MEMORY  │   │ CONTROL  │          │
│  │ REGISTER │   │ (ROM+RAM)│   │(microcode)│          │
│  └──────────┘   └──────────┘   └──────────┘          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Module 1: Register File (U1-U8)

### What it does:
**8 boxes that remember numbers.** Each box holds one byte (0-255).

### Analogy:
Like 8 labeled jars on a shelf. You can:
- **Look** at one jar (read → put value on bus)
- **Put** a number into one jar (write → latch from ALU result)
- Only ONE jar open at a time

### Chips: 8× 74HC574

### How it works:
```
READ:  Decoder U20 opens one jar's lid (/OE=LOW)
       → that jar's number appears on the bus (IBUS)
       → all other jars stay closed (/OE=HIGH)

WRITE: Decoder U21 taps one jar (CLK pulse)
       → that jar captures the number from ALU result
       → all other jars ignore the tap
```

### Test it:
1. Put DIP switches on IBUS (set a number manually)
2. Pulse one register's CLK → it stores the number
3. Enable that register's /OE → LEDs on IBUS show the stored number
4. Try different registers — each remembers its own number

### Debug checklist:
- [ ] Only ONE /OE is LOW at a time (check U20 outputs)
- [ ] CLK only pulses when you want to write (check U21)
- [ ] r0 never changes (CLK tied to GND)
- [ ] After reset, all registers = 0

---

## Module 2: ALU — Arithmetic Logic Unit (U12-U15, U25)

### What it does:
**A calculator.** Takes two numbers, does math, gives result.

### Analogy:
Like a calculator with two input slots:
- Slot A: number from the bus (the register you're reading)
- Slot B: number from operand or another register
- Output: the answer (goes to result latch, then to registers)

### Chips: 2× 74HC283 (adder) + 2× 74HC86 (XOR) + 1× 74HC574 (result latch)

### How it works:
```
ADD: A + B → result
SUB: A + (NOT B) + 1 → result  (XOR flips B, carry_in=1)
AND: done by microcode (pass through with mask)
```

The XOR chips (U14, U15) flip the B input when SUB mode is active:
```
ALU_SUB = 0: B passes through unchanged → ADD
ALU_SUB = 1: B gets inverted (XOR with 1) → SUB
```

### Test it:
1. Set IBUS = 5 (from a register or DIP switch)
2. Set ALUB = 3 (from operand latch)
3. ALU_SUB = 0 → result should be 8 (5+3)
4. ALU_SUB = 1 → result should be 2 (5-3)
5. Pulse ALUR_CLK → result latch captures answer
6. Check ALU_R LEDs

### Debug checklist:
- [ ] XOR outputs match: SUB=0 → same as input, SUB=1 → inverted
- [ ] Carry chain: U12.C4 connects to U13.C0
- [ ] C0 of U12 = ALU_SUB (1 for subtract, 0 for add)
- [ ] Result latch (U25) captures on ALUR_CLK rising edge

---

## Module 3: Program Counter — PC (U16-U17)

### What it does:
**Points to the current instruction in ROM.** Like a bookmark that moves forward.

### Analogy:
Like your finger pointing at a line in a book. After reading each line, your finger moves to the next one.

### Chips: 2× 74HC574 (PC low + PC high, with /OE)

### How it works:
```
FETCH: PC drives address bus → ROM sends back the instruction
       Then microcode computes PC+1 via ALU → loads back into PC

BRANCH: Microcode computes PC+offset via ALU → loads new value

DATA ACCESS: PC disconnects (/OE=HIGH), address latches take over
```

### Why 74HC574 (not 74HC161 counter)?
Because 574 has **/OE** — can disconnect from address bus. Counter (161) can't disconnect, would conflict with address latches during memory access.

### Test it:
1. Load PC with a value (pulse PC_LO_CLK with data on ALU_R)
2. Check ADDR LEDs — should show PC value
3. Set DATA_MODE=HIGH → PC disconnects, ADDR goes to whatever latches hold
4. Set DATA_MODE=LOW → PC reconnects

### Debug checklist:
- [ ] DATA_MODE=0: PC drives ADDR (U16./OE=LOW, U18./OE=HIGH)
- [ ] DATA_MODE=1: Latches drive ADDR (U16./OE=HIGH, U18./OE=LOW)
- [ ] Never both LOW at same time (bus conflict!)
- [ ] PC loads from ALU_R bus (same as registers)

---

## Module 4: Instruction Register — IR (U9-U11)

### What it does:
**Remembers what instruction the CPU is currently doing.**

### Analogy:
Like writing down a recipe step on a sticky note so you don't forget while cooking.

### Chips: 3× 74HC574 (opcode + operand + ALU B latch)

### How it works:
```
Step 1: ROM data → IBUS → U9 latches OPCODE (what to do)
Step 2: ROM data → IBUS → U10 latches OPERAND (with what number)

For register-register ops:
Step extra: source register → IBUS → U11 latches ALU B value
```

### The opcode tells the microcode what to do:
```
Bits [7:6] = class:  00=math, 01=immediate, 10=memory, 11=control
Bits [5:3] = operation: ADD/SUB/AND/OR/etc.
Bits [2:0] = which register
```

### Test it:
1. Put $41 on IBUS (= "LI r1" opcode)
2. Pulse IR_CLK → U9 captures $41
3. Check U9 outputs → should show 01_000_001
4. Put $42 on IBUS (= the immediate value)
5. Pulse OPR_CLK → U10 captures $42

### Debug checklist:
- [ ] U9 outputs go to Flash address pins (opcode → microcode lookup)
- [ ] U10 outputs go to ALUB (for immediate operations)
- [ ] U11 outputs also go to ALUB (shared wire, only one /OE active)
- [ ] U10./OE and U11./OE are never both LOW

---

## Module 5: Memory Interface (U18-U19, U22, ROM, RAM)

### What it does:
**Reads programs from ROM and reads/writes data to RAM.**

### Analogy:
Like a library:
- ROM = reference books (read only, contains your program)
- RAM = your notebook (read and write, stores variables)
- Address = shelf number (which book/page)
- Data = what's written on that page

### Chips: 2× 74HC574 (address latches) + 1× 74HC245 (bus buffer) + ROM + RAM

### How it works:
```
FETCH (reading program):
  PC → ADDR → ROM → DEXT → U22 buffer → IBUS → IR

DATA READ (LB instruction):
  Register value → IBUS → U18/U19 (address latches) → ADDR → RAM → DEXT → U22 → IBUS → register

DATA WRITE (SB instruction):
  Register value → IBUS → U22 → DEXT → RAM (at address from latches)
```

### The 74HC245 buffer (U22):
```
DIR=0 (read):  external data → IBUS  (ROM/RAM → CPU)
DIR=1 (write): IBUS → external data  (CPU → RAM)
/OE=LOW: buffer active (only during memory steps)
/OE=HIGH: buffer disconnected (during ALU operations)
```

### Test it:
1. Set address latches to $0042 (load via IBUS)
2. Set DATA_MODE=1 (latches drive ADDR)
3. Check ADDR LEDs = $0042
4. If RAM has data at $0042, it appears on DEXT
5. Enable U22 (BUF_OE=LOW, DIR=0) → data appears on IBUS

### Debug checklist:
- [ ] Address latches only capture when their CLK pulses
- [ ] U22 /OE is HIGH during non-memory steps (disconnected)
- [ ] DIR matches read vs write
- [ ] ROM /CE and RAM /CE don't conflict (use ADDR15 to select)

---

## Module 6: Control — Microcode Flash (U23, U24)

### What it does:
**The brain. Tells every other module what to do each clock cycle.**

### Analogy:
Like a conductor in an orchestra. Each musician (chip) knows how to play, but the conductor tells them WHEN to play and WHAT note.

### Chips: 1× SST39SF010A (Flash) + 1× 74HC74 (flags)

### How it works:
```
Every clock cycle:
  1. Flash reads: {step_number, opcode, flags}
  2. Flash outputs: 8 control bits
  3. Those bits directly control: who reads, who writes, ALU mode, etc.

The Flash is just a BIG LOOKUP TABLE:
  "If we're on step 2 of an ADD instruction and Z=0, then:
   enable register r2 to drive bus, and pulse ALU B latch"
```

### The step counter:
```
Steps cycle: 0 → 1 → 2 → 3 → 4 → 0 → 1 → ...
Each instruction takes 4-6 steps.
Step counter is just the lowest bits of a free-running counter.
```

### Flags (U24):
```
Z flag: "was the last result zero?" (1=yes, 0=no)
C flag: "did the last add overflow?" (1=yes, 0=no)
These feed into Flash address → microcode knows flag state → decides branch
```

### Test it:
1. Set Flash address manually (step=0, opcode=$41, flags=00)
2. Read Flash output → should be the control word for "fetch step 0 of LI r1"
3. Change step → output changes (different control for each step)
4. This is how you debug: check if Flash outputs match expected control

### Debug checklist:
- [ ] Flash address pins connected to: step counter + U9 outputs + U24 outputs
- [ ] Flash /CE = GND (always selected)
- [ ] Flash /OE = GND (always reading)
- [ ] Flash outputs go to the right control points
- [ ] Step counter advances every CLK

---

## Build Order (recommended):

```
1. Module 6 (Control) — get Flash outputting signals
2. Module 3 (PC) — get address counting
3. Module 5 (Memory) — read ROM data
4. Module 4 (IR) — latch instructions
5. Module 1 (Registers) — store values
6. Module 2 (ALU) — do math

Test after each module. Don't move on until current module works!
```

---

## How They All Work Together (one instruction: ADDI r1, $05):

```
Step 0: Control says "PC drives ADDR, read ROM, latch IR"
        → PC=C000 → ADDR=C000 → ROM[$C000]=$49 → IBUS=$49 → U9 latches $49

Step 1: Control says "PC drives ADDR, read ROM, latch operand, PC+1"
        → PC=C001 → ADDR=C001 → ROM[$C001]=$05 → IBUS=$05 → U10 latches $05

Step 2: Control says "r1 drives IBUS, operand drives ALUB, compute ADD"
        → U20 enables r1 → IBUS=r1 value → ALU computes IBUS+ALUB
        → ALU_SUB=0, result = r1 + $05

Step 3: Control says "latch result, write to r1, PC+1"
        → U25 latches ALU output → ALU_R = result
        → U21 pulses r1 CLK → r1 captures new value
        → PC incremented for next instruction

Done! r1 now holds old_r1 + 5.
```

---

# ภาษาไทย — เข้าใจ CPU ทีละส่วน (ง่ายมากๆ สำหรับเด็กประถม)

---

## CPU คืออะไร?

**CPU = สมองของคอมพิวเตอร์**

มันทำแค่ 3 อย่าง:
1. 📖 **อ่าน** คำสั่ง (จาก ROM)
2. 🧮 **คิด** (บวก ลบ เปรียบเทียบ)
3. 📝 **จำ** ผลลัพธ์ (ใส่กล่อง)

ทำซ้ำ 3 อย่างนี้ ล้านครั้งต่อวินาที = คอมพิวเตอร์ทำงาน!

---

## 6 ส่วนของ CPU (เหมือนร่างกาย)

```
🧠 สมอง (Control)     = บอกทุกส่วนว่าต้องทำอะไร
👀 ตา (IR)            = อ่านคำสั่ง
🖐️ มือ (Registers)    = จับของ (เก็บตัวเลข)
🧮 เครื่องคิดเลข (ALU) = บวก ลบ
👆 นิ้วชี้ (PC)        = ชี้ว่าอ่านถึงไหนแล้ว
📚 หนังสือ (Memory)    = เก็บโปรแกรมและข้อมูล
```

---

## ส่วนที่ 1: กล่องเก็บของ (Registers) 📦

### มันคืออะไร?
**กล่อง 8 ใบ** ที่เก็บตัวเลขได้ 1 ตัวต่อกล่อง (0 ถึง 255)

### เปรียบเทียบ:
เหมือน **ลิ้นชัก 8 ช่อง** บนโต๊ะ
- เปิดได้ทีละ 1 ช่อง
- ดูตัวเลขข้างใน (อ่าน)
- ใส่ตัวเลขใหม่ (เขียน)

### ชื่อกล่อง:
```
กล่อง 0: ว่างเสมอ (= 0 ตลอด)
กล่อง 1: ผลลัพธ์ (a0)
กล่อง 2: ของที่ส่งมา (a1)
กล่อง 3: ของชั่วคราว (t0)
กล่อง 4: ของชั่วคราว (t1)
กล่อง 5: ของเก็บ (s0)
กล่อง 6: ของเก็บ (s1)
กล่อง 7: ที่อยู่กลับ (ra/sp)
```

### ทดสอบ:
1. ใส่เลข 42 เข้ากล่อง 1
2. เปิดกล่อง 1 ดู → ต้องเห็น 42
3. ใส่เลข 99 เข้ากล่อง 2
4. เปิดกล่อง 2 ดู → ต้องเห็น 99
5. เปิดกล่อง 1 อีกที → ยังเป็น 42 (ไม่หาย!)

---

## ส่วนที่ 2: เครื่องคิดเลข (ALU) 🧮

### มันคืออะไร?
**เครื่องบวกเลข** รับ 2 ตัวเลข ให้คำตอบ 1 ตัว

### เปรียบเทียบ:
เหมือน **เครื่องคิดเลข** ที่มีแค่ปุ่ม + กับ -

```
ช่อง A: ตัวเลขแรก (จากกล่อง)
ช่อง B: ตัวเลขที่สอง (จากคำสั่ง)
คำตอบ: A + B หรือ A - B
```

### ทดสอบ:
1. ใส่ A = 5
2. ใส่ B = 3
3. กด + → คำตอบ = 8 ✅
4. กด - → คำตอบ = 2 ✅

---

## ส่วนที่ 3: นิ้วชี้ (PC — Program Counter) 👆

### มันคืออะไร?
**ตัวนับ** ที่บอกว่า "อ่านคำสั่งถึงบรรทัดไหนแล้ว"

### เปรียบเทียบ:
เหมือน **นิ้วชี้ตามบรรทัด** ตอนอ่านหนังสือ
- อ่านจบบรรทัด → เลื่อนนิ้วไปบรรทัดถัดไป
- ถ้าเจอ "ข้ามไป" → กระโดดนิ้วไปบรรทัดอื่น

### ทดสอบ:
1. เริ่มที่บรรทัด 0
2. กด clock 1 ครั้ง → นิ้วเลื่อนไปบรรทัด 1
3. กด clock อีก → บรรทัด 2, 3, 4...
4. กด reset → กลับไปบรรทัด 0

---

## ส่วนที่ 4: ตาอ่าน (IR — Instruction Register) 👀

### มันคืออะไร?
**จำคำสั่งที่เพิ่งอ่าน** เพื่อไม่ลืมระหว่างทำงาน

### เปรียบเทียบ:
เหมือน **จดโน้ต** ก่อนทำ
- อ่านคำสั่ง: "บวก 5"
- จดไว้: "บวก" (opcode) + "5" (operand)
- แล้วค่อยทำตามที่จด

### ทดสอบ:
1. ส่งคำสั่ง "บวก 5" เข้ามา
2. ดู LED → ต้องเห็น "บวก" ที่ช่อง opcode
3. ดู LED → ต้องเห็น "5" ที่ช่อง operand

---

## ส่วนที่ 5: หนังสือ (Memory — ROM + RAM) 📚

### มันคืออะไร?
- **ROM** = หนังสือเรียน (อ่านได้อย่างเดียว, เก็บโปรแกรม)
- **RAM** = สมุดจด (อ่าน+เขียนได้, เก็บข้อมูล)

### เปรียบเทียบ:
```
ROM = ตำราอาหาร (สูตรไม่เปลี่ยน)
RAM = กระดาษทด (จดอะไรก็ได้ ลบได้)
```

### ทดสอบ:
1. อ่าน ROM ที่ตำแหน่ง 0 → ได้คำสั่งแรก
2. เขียน 99 ลง RAM ที่ตำแหน่ง 10
3. อ่าน RAM ที่ตำแหน่ง 10 → ต้องได้ 99

---

## ส่วนที่ 6: สมอง (Control — Microcode) 🧠

### มันคืออะไร?
**ผู้ควบคุมวง** บอกทุกส่วนว่าต้องทำอะไร ตอนไหน

### เปรียบเทียบ:
เหมือน **วาทยกร** (conductor) ในวงดนตรี
- นักดนตรีทุกคนรู้วิธีเล่น
- แต่วาทยกรบอกว่า "ตอนนี้ใครเล่น" และ "เล่นอะไร"

### มันทำอะไร:
```
ทุก clock:
  1. ดูว่าเราอยู่ขั้นตอนไหน (step 0? 1? 2?)
  2. ดูว่าคำสั่งคืออะไร (บวก? ลบ? อ่าน?)
  3. ส่งสัญญาณ: "กล่อง 2 เปิด!" "เครื่องคิดเลข บวก!" "กล่อง 1 จำ!"
```

### ทดสอบ:
1. ตั้งคำสั่ง = "LI r1, 42" (ใส่ 42 เข้ากล่อง 1)
2. กด clock ทีละครั้ง
3. ดูว่าสมองส่งสัญญาณถูก:
   - step 0: "อ่านคำสั่ง!"
   - step 1: "อ่านตัวเลข!"
   - step 2: "ส่ง 42 เข้าเครื่องคิดเลข!"
   - step 3: "เก็บผลลัพธ์ลงกล่อง 1!"
4. ดูกล่อง 1 → ต้องเห็น 42 ✅

---

## ทุกส่วนทำงานร่วมกัน (ตัวอย่าง: ADDI r1, 5)

```
📖 "บวก 5 ใส่กล่อง 1"

ขั้นตอน:
  👆 นิ้วชี้บรรทัด 0 → 👀 ตาอ่าน "ADDI r1, 5"
  🧠 สมองสั่ง: "กล่อง 1 เปิด!"
  🖐️ มือหยิบเลขจากกล่อง 1 (สมมุติ = 10)
  🧠 สมองสั่ง: "เครื่องคิดเลข บวก 5!"
  🧮 เครื่องคิดเลข: 10 + 5 = 15
  🧠 สมองสั่ง: "เก็บ 15 ลงกล่อง 1!"
  📦 กล่อง 1 = 15 ✅
  👆 นิ้วเลื่อนไปบรรทัดถัดไป
```

---

## สรุป

| ส่วน | เปรียบเทียบ | ทำอะไร |
|:----:|:-----------:|--------|
| 📦 Registers | ลิ้นชัก 8 ช่อง | เก็บตัวเลข |
| 🧮 ALU | เครื่องคิดเลข | บวก ลบ |
| 👆 PC | นิ้วชี้ตามบรรทัด | บอกว่าอ่านถึงไหน |
| 👀 IR | จดโน้ต | จำคำสั่งที่อ่าน |
| 📚 Memory | หนังสือ + สมุดจด | เก็บโปรแกรม + ข้อมูล |
| 🧠 Control | วาทยกร | สั่งทุกส่วนให้ทำงาน |

**แค่ 6 ส่วนนี้ = คอมพิวเตอร์ 1 เครื่อง!** 🎉
