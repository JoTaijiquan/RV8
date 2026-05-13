# Lab 8: Flags and Control Unit

## Objective
Wire the flags, instruction decoder, and state machine. The CPU runs programs autonomously.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC138 | 1 | 3-to-8 decoder (unit decode) |
| 74HC74 | 2 | Dual D flip-flop (flags + state) |
| 74HC08 | 1 | Quad AND gate (signal generation) |
| 74HC32 | 1 | Quad OR gate (signal combining) |

## Concept

The control unit reads the opcode and generates all control signals:
```
opcode[7:5] → 74HC138 → which unit is active (ALU/IMM/LDST/BRANCH/...)
opcode[4:2] → operation select within that unit
state machine → timing: when to fetch, execute, access memory
flags (Z,C,N) → branch decisions
```

## Schematic

```
U18 (74HC138, unit decode):
  A ← opcode[5], B ← opcode[6], C ← opcode[7]
  /G2A ← execute_phase (only active during execute)
  G1 ← VCC
  /Y0 = ALU unit,  /Y1 = IMM unit,  /Y2 = LDST unit
  /Y3 = BRANCH,    /Y4 = SHIFT,     /Y7 = SYSTEM

U20 (74HC74, flags):
  FF1: D ← alu_zero (NOR of all result bits)
       CLK ← flags_clk (active when ALU instruction executes)
       Q = Z flag
  FF2: D ← alu_carry (U14.C4)
       CLK ← flags_clk
       Q = C flag

U21 (74HC74, state + N flag):
  FF1: D ← result[7]
       CLK ← flags_clk
       Q = N flag
  FF2: D ← state toggle (next state logic)
       CLK ← CLK
       Q = state bit

U22 (74HC08, AND gates):
  Gate 1: ir0_clk = CLK AND state_S0
  Gate 2: ir1_clk = CLK AND state_S1
  Gate 3: a0_clk = execute AND is_alu_unit
  Gate 4: pc_inc = state_S0 OR state_S1

U23 (74HC32, OR gates):
  Gate 1: flags_clk = (is_alu OR is_imm_alu) AND execute
  Gate 2: mem_rd = state_S0 OR state_S1 OR (is_load AND state_S2)
  Gate 3: mem_wr = is_store AND state_S2
  Gate 4: (spare / combining)
```

## Simulate First

```bash
cd sim/
iverilog -o lab8 ../rv8_cpu.v lab8_cpu_tb.v && vvp lab8
gtkwave lab8.vcd
```

**What to check in GTKWave:**
- `addr_bus`: fetches from $C000 sequentially
- `halt`: asserts after loop completes
- CPU executes LI, ADDI, CMPI, BNE loop, then HLT
- Full program runs autonomously

---

## Procedure

1. Insert U18 (74HC138). Wire opcode[7:5] from U5 to inputs A,B,C.
2. Insert U20 (74HC74). Wire ALU zero detect (8-input NOR or cascaded OR+invert) to FF1.D. Wire carry from U14.C4 to FF2.D.
3. Insert U21 (74HC74). Wire result[7] to FF1.D. Use FF2 for state machine.
4. Insert U22 (74HC08). Wire clock gating:
   - Gate 1: CLK AND /state → ir0_clk (drives U5)
   - Gate 2: CLK AND state → ir1_clk (drives U6)
5. Insert U23 (74HC32). Wire control signal combining.
6. Connect control outputs to previously-built modules:
   - a0_clk → U7 (a0 register)
   - pc_inc → U1-U4 ENP/ENT
   - addr_sel → U16-U17 (address mux)
   - mem_rd → 74HC245 /OE + RAM /OE
   - mem_wr → RAM /WE
7. Remove all manual switches/buttons from previous labs.
8. Program ROM with test programs.

## Test Programs

### Test A: Load Immediate
```
ROM contents:
$0000: $11 $05    ; LI a0, 5
$0002: $FF $00    ; HLT
```
Expected: a0 LEDs show $05, CPU halts.

### Test B: Add Immediate
```
$0000: $11 $05    ; LI a0, 5
$0002: $16 $03    ; ADDI 3
$0004: $FF $00    ; HLT
```
Expected: a0 = $08.

### Test C: Loop
```
$0000: $11 $00    ; LI a0, 0
$0002: $16 $01    ; ADDI 1
$0004: $18 $0A    ; CMPI 10
$0006: $31 $FA    ; BNE -6 (back to $0002)
$0008: $FF $00    ; HLT
```
Expected: a0 = $0A when halted. In RUN mode, LEDs count up rapidly then stop.

### Test D: Memory Store/Load
```
$0000: $11 $42    ; LI a0, $42
$0002: $13 $20    ; LI ph, $20
$0004: $12 $00    ; LI pl, $00
$0006: $23 $00    ; SB (ptr+)
$0008: $11 $00    ; LI a0, 0
$000A: $49 $00    ; DEC16
$000C: $20 $00    ; LB (ptr)
$000E: $FF $00    ; HLT
```
Expected: a0 = $42 (wrote to RAM, read back).

## Test Procedure

| Test | Program | Single-step verify | RUN mode verify |
|:----:|---------|-------------------|-----------------|
| A | LI + HLT | a0=$05 after 2 cycles, HALT asserts | a0 LEDs show $05 |
| B | LI + ADDI + HLT | a0=$08 after 4 cycles | a0 LEDs show $08 |
| C | Loop | Step through: a0 increments each iteration | LEDs count then stop at $0A |
| D | Store/Load | Verify RAM write, pointer, read-back | a0 shows $42 |

## Checkoff

- [ ] LI a0, N: loads immediate into a0
- [ ] ADDI N: adds immediate to a0
- [ ] CMPI + BNE: loop executes correct number of times
- [ ] SB/LB via pointer: RAM write and read-back works
- [ ] HLT: CPU stops (clock gated or PC stops incrementing)
- [ ] RESET: CPU restarts from beginning
- [ ] All tests pass in both STEP and RUN modes

## Congratulations!

If all tests pass, you have a **working RV8 CPU**. It can:
- Execute arithmetic (ADD, SUB, AND, OR, XOR)
- Load/store memory via pointer
- Branch conditionally (loops, if-else)
- Halt and reset

Next: connect the trainer board for serial programming and I/O.

## Thai Version

---

# แลป 8: Flags และ Control Unit (หน่วยควบคุม)

---

## เป้าหมาย

ต่อ flags, ตัวถอดรหัสคำสั่ง, และ state machine เข้าด้วยกัน — CPU รันโปรแกรมเองได้!

---

## ความรู้พื้นฐาน

**Control Unit** = สมองของ CPU อ่าน opcode แล้วสั่งว่าต้องทำอะไร

**Flags** = ธงบอกผลลัพธ์:
- Z (Zero) = ผลลัพธ์เป็น 0
- C (Carry) = มีทด/ไม่มี borrow
- N (Negative) = ผลลัพธ์เป็นลบ (บิต 7 = 1)

**74HC138** = ถอดรหัส opcode[7:5] เพื่อเลือกว่าเป็นคำสั่งกลุ่มไหน (ALU, Branch, Load/Store...)

**State Machine** = ลำดับขั้นตอน: Fetch → Execute → Memory → Fetch...

---

## อุปกรณ์

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC138 | 1 | ถอดรหัสกลุ่มคำสั่ง |
| 74HC74 | 2 | เก็บ flags (Z,C,N) + state |
| 74HC08 | 1 | AND gate สร้างสัญญาณควบคุม |
| 74HC32 | 1 | OR gate รวมสัญญาณ |

---

## หลักการทำงาน

```
opcode [7:5] ──► 74HC138 ──► กลุ่มคำสั่งไหน?
opcode [4:0] ──► logic ──► ทำอะไรในกลุ่มนั้น?
flags (Z,C,N) ──► logic ──► branch ไปไหม?
state ──► logic ──► ตอนนี้ fetch หรือ execute?
                         │
                         ▼
              สัญญาณควบคุมทั้งหมด:
              a0_clk, pc_inc, mem_rd, mem_wr, addr_sel...
```

---

## ขั้นตอนต่อวงจร

1. เสียบ U18 (74HC138) ต่อ opcode[7:5] จาก U5 → input A,B,C
2. เสียบ U20 (74HC74) ต่อ:
   - FF1: D ← Zero detect (ผลลัพธ์ = 0?), CLK ← flags_clk → Q = Z flag
   - FF2: D ← Carry จาก ALU, CLK ← flags_clk → Q = C flag
3. เสียบ U21 (74HC74) ต่อ:
   - FF1: D ← result[7], CLK ← flags_clk → Q = N flag
   - FF2: ใช้สำหรับ state machine
4. เสียบ U22 (74HC08) สร้าง clock gating:
   - ir0_clk = CLK AND state_S0
   - ir1_clk = CLK AND state_S1
5. เสียบ U23 (74HC32) รวมสัญญาณควบคุม
6. ต่อสัญญาณควบคุมไปยังโมดูลที่สร้างไว้:
   - a0_clk → U7, pc_inc → U1–U4, addr_sel → U16–U17
   - mem_rd → 74HC245, mem_wr → RAM
7. **ถอดปุ่มกดและสวิตช์ทั้งหมดออก** (ยกเว้น STEP/RUN/RESET)
8. โปรแกรม ROM ด้วยโปรแกรมทดสอบ

---

## โปรแกรมทดสอบ

### ทดสอบ A: โหลดค่า
```
$0000: $11 $05    ; LI a0, 5
$0002: $FF $00    ; HLT
```
คาดหวัง: LED a0 แสดง $05 แล้ว CPU หยุด

### ทดสอบ B: บวก
```
$0000: $11 $05    ; LI a0, 5
$0002: $16 $03    ; ADDI 3
$0004: $FF $00    ; HLT
```
คาดหวัง: a0 = $08

### ทดสอบ C: วนลูป (นับถึง 10)
```
$0000: $11 $00    ; LI a0, 0
$0002: $16 $01    ; ADDI 1
$0004: $18 $0A    ; CMPI 10
$0006: $31 $FA    ; BNE -6 (กลับไป $0002)
$0008: $FF $00    ; HLT
```
คาดหวัง: a0 = $0A เมื่อหยุด ใน RUN mode LED นับขึ้นเร็วแล้วหยุดที่ 10

### ทดสอบ D: เขียน/อ่าน RAM
```
$0000: $11 $42    ; LI a0, $42
$0002: $13 $20    ; LI ph, $20
$0004: $12 $00    ; LI pl, $00
$0006: $23 $00    ; SB (ptr+)
$0008: $11 $00    ; LI a0, 0
$000A: $49 $00    ; DEC16
$000C: $20 $00    ; LB (ptr)
$000E: $FF $00    ; HLT
```
คาดหวัง: a0 = $42 (เขียนลง RAM แล้วอ่านกลับ)

---

## ทดสอบ

| ขั้น | โปรแกรม | STEP mode | RUN mode |
|:----:|---------|-----------|----------|
| A | LI + HLT | a0=$05 หลัง 2 cycle | LED แสดง $05 |
| B | LI + ADDI + HLT | a0=$08 หลัง 4 cycle | LED แสดง $08 |
| C | วนลูป | a0 เพิ่มทีละ 1 ทุกรอบ | LED นับแล้วหยุดที่ $0A |
| D | Store/Load | ตรวจ RAM ทีละ step | LED แสดง $42 |

---

## เช็คลิสต์ผ่าน

- [ ] LI a0, N: โหลดค่าเข้า a0 ถูกต้อง
- [ ] ADDI N: บวกค่าเข้า a0 ถูกต้อง
- [ ] CMPI + BNE: วนลูปจำนวนรอบถูกต้อง
- [ ] SB/LB ผ่าน pointer: เขียนและอ่าน RAM ได้
- [ ] HLT: CPU หยุดทำงาน
- [ ] RESET: CPU เริ่มใหม่จากต้น
- [ ] ทดสอบผ่านทั้ง STEP mode และ RUN mode

---

## จำลองก่อนต่อจริง

```bash
cd sim/
iverilog -o lab8 ../rv8_cpu.v lab8_cpu_tb.v && vvp lab8
gtkwave lab8.vcd
```

---

## 🎉 ยินดีด้วย!

ถ้าทดสอบผ่านทั้งหมด คุณมี **RV8 CPU ที่ทำงานได้จริง** แล้ว! มันสามารถ:
- คำนวณ (บวก ลบ AND OR XOR)
- อ่าน/เขียนหน่วยความจำ
- วนลูปและตัดสินใจ (branch)
- หยุดและเริ่มใหม่

ขั้นตอนถัดไป: ต่อ Trainer Board สำหรับโปรแกรมผ่าน serial และ I/O
