# Lab 10: Stack and Subroutines

## Objective
Add stack operations (PUSH/POP) and subroutine calls (JAL/RET) using the SP register and stack page.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| (no new chips) | — | Uses existing SP register (U9) + address mux + RAM |

## Concept

The stack lives at page $30 (address $3000–$30FF). SP is an 8-bit register that indexes into this page.

```
PUSH: sp = sp - 1; mem[{$30, sp}] = value
POP:  value = mem[{$30, sp}]; sp = sp + 1
JAL:  push PCH; push PCL; PC = {ph, pl}
RET:  pop PCL; pop PCH
```

The address mux needs a new mode:
- addr_sel=2: address = {$30, SP} (stack access)
- addr_sel=7: address = {$30, SP-1} (pre-decrement for PUSH)

## New Instructions Enabled

| Opcode | Instruction | Operation |
|:------:|-------------|-----------|
| 0x2C | PUSH rs | sp--; mem[{$30,sp}] = reg |
| 0x2D | POP rd | reg = mem[{$30,sp}]; sp++ |
| 0x3D | JAL | push PCH, push PCL; PC = {ph,pl} |
| 0x3E | RET | pop PCL; pop PCH |

## Schematic

```
Stack address generation:
  addr_sel=2: {$30, SP}       ← POP/RET (read from current SP)
  addr_sel=7: {$30, SP - 1}   ← PUSH/JAL (write to SP-1, then decrement)

SP register (U9, 74HC574):
  Already built in Lab 6
  Add: sp_inc signal (for POP/RET)
  Add: sp_dec signal (for PUSH/JAL)

Multi-cycle state machine for JAL:
  S2: push PCH to stack, sp--
  S3: push PCL to stack, sp--
  S4: load PC from {ph, pl}

Multi-cycle state machine for RET:
  S2: read PCL from stack, sp++, store in temp
  S3: read PCH from stack, sp++, load PC = {PCH, PCL}
```

## Procedure

1. Add sp_inc and sp_dec logic to SP register (U9):
   - sp_inc: on POP/RET states, increment SP after read
   - sp_dec: on PUSH/JAL states, decrement SP before write
   - Use 74HC283 (spare adder) or 74HC161 as up/down counter
2. Add stack address mode to address mux:
   - Wire $30 to high byte when addr_sel=2 or 7
   - Wire SP output to low byte (addr_sel=2) or SP-1 to low byte (addr_sel=7)
3. Add data_out mux for PUSH/JAL:
   - PUSH: output = register value (selected by operand)
   - JAL S2: output = PC high byte
   - JAL S3: output = PC low byte
4. Extend state machine: add S2/S3/S4 states for multi-cycle ops.
5. Update control decode for opcodes $2C, $2D, $3D, $3E.

## Test Procedure

| Test | Program | Expected |
|:----:|---------|----------|
| 1 | LI sp,$FF / LI a0,$42 / PUSH a0 / LI a0,$00 / POP a0 / HLT | a0 = $42 |
| 2 | LI sp,$FF / LI a0,$11 / PUSH a0 / LI a0,$22 / PUSH a0 / POP a0 / POP a0 / HLT | a0 = $11 (LIFO) |
| 3 | LI pl,$20 / LI ph,$C0 / JAL / HLT ← (at $C020: LI a0,$77 / RET) | a0 = $77 |
| 4 | Nested: JAL to sub1, sub1 calls sub2, sub2 returns, sub1 returns | Correct return addresses |

## Checkoff

- [ ] PUSH: writes value to stack, SP decrements
- [ ] POP: reads value from stack, SP increments
- [ ] PUSH/POP pair: value preserved (round-trip)
- [ ] Multiple PUSH/POP: LIFO order correct
- [ ] JAL: pushes return address, jumps to {ph,pl}
- [ ] RET: pops return address, resumes after JAL
- [ ] Nested calls: 2+ levels of JAL/RET work

## Notes
- SP starts at $FF (top of stack page). First PUSH writes to $30FE.
- Stack grows downward (PUSH decrements, POP increments).
- JAL/RET are 5-cycle instructions (fetch + 3 stack ops + jump).
- After this lab: PUSH, POP, JAL, RET all work. Combined with Lab 8: **27 instructions total**.

---

## Thai Version

---

# แลป 10: Stack และ Subroutine (กองซ้อนและฟังก์ชัน)

---

## เป้าหมาย

เพิ่ม PUSH/POP (เก็บ/ดึงค่าจากกอง) และ JAL/RET (เรียก/กลับจากฟังก์ชัน)

---

## ความรู้พื้นฐาน

**Stack (กองซ้อน)** = ที่เก็บของชั่วคราว ทำงานแบบ "เข้าหลังออกก่อน" (LIFO)
- เหมือนกองจาน: วางจานใหม่ข้างบน หยิบจานบนสุดออก

**PUSH** = วางของลงกอง (SP ลด 1, เขียนค่า)

**POP** = หยิบของออกจากกอง (อ่านค่า, SP เพิ่ม 1)

**JAL (Jump And Link)** = เรียกฟังก์ชัน (เก็บที่อยู่กลับลง stack แล้วกระโดด)

**RET (Return)** = กลับจากฟังก์ชัน (ดึงที่อยู่กลับจาก stack)

**Stack อยู่ที่ page $30** → address = {$30, SP} เช่น SP=$FE → address $30FE

---

## อุปกรณ์เพิ่มเติม

ไม่ต้องเพิ่มชิปใหม่ — ใช้ SP register (U9) + address mux + RAM ที่มีอยู่

---

## ขั้นตอนต่อวงจร

1. เพิ่ม sp_inc / sp_dec ให้ SP register (ใช้ 74HC161 หรือ adder)
2. เพิ่ม address mode ใหม่: {$30, SP} สำหรับ POP, {$30, SP-1} สำหรับ PUSH
3. เพิ่ม data_out mux: PUSH ส่งค่า register, JAL ส่ง PC
4. ขยาย state machine: เพิ่ม S2/S3/S4 สำหรับ multi-cycle ops
5. อัพเดท decode สำหรับ opcode $2C, $2D, $3D, $3E

---

## ทดสอบ

| ขั้น | โปรแกรม | ผลที่ถูกต้อง |
|:----:|---------|-------------|
| 1 | LI a0,$42 / PUSH / LI a0,0 / POP | a0 = $42 (เก็บแล้วดึงกลับ) |
| 2 | PUSH $11 / PUSH $22 / POP / POP | ได้ $22 ก่อน แล้ว $11 (LIFO) |
| 3 | JAL ไปฟังก์ชัน / ฟังก์ชัน RET | กลับมาทำงานต่อหลัง JAL |
| 4 | ฟังก์ชันซ้อน 2 ชั้น | กลับถูกทุกชั้น |

---

## เช็คลิสต์ผ่าน

- [ ] PUSH: เขียนค่าลง stack, SP ลด
- [ ] POP: อ่านค่าจาก stack, SP เพิ่ม
- [ ] PUSH/POP คู่กัน: ค่าไม่หาย
- [ ] JAL: กระโดดไปฟังก์ชัน + เก็บที่อยู่กลับ
- [ ] RET: กลับมาทำงานต่อหลัง JAL
- [ ] ซ้อนกัน 2+ ชั้นทำงานถูก

---

## หมายเหตุ

- SP เริ่มที่ $FF (บนสุดของ stack) PUSH แรกเขียนที่ $30FE
- Stack โตลง (PUSH ลด SP, POP เพิ่ม SP)
- หลัง Lab นี้: เพิ่ม PUSH, POP, JAL, RET = **31 คำสั่งทำงานได้**
