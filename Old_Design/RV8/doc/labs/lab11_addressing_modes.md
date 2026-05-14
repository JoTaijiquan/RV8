# Lab 11: Addressing Modes and Register Routing

## Objective
Add all remaining addressing modes (zero-page, sp+imm, pg:imm) and register routing (LI to all registers, MOV, constant generator).

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC157 | 1 | Mux for register write select (or decode with existing 138) |
| (wiring changes) | — | Additional address mux inputs, register routing |

## Concept

After Labs 8–10, the CPU can only:
- Load immediate into a0
- Access memory via pointer

The full RV8 needs:
- **LI to any register** (sp, a0, pl, ph, t0, pg)
- **MOV** between registers
- **Zero-page** addressing: mem[{$00, imm8}] — fast globals
- **SP+imm** addressing: mem[{$30, sp+imm8}] — local variables
- **Page-relative** addressing: mem[{pg, imm8}] — paged access
- **Constant generator**: register x0 returns 0, 1, $FF, or $80

## New Instructions Enabled

| Opcode | Instruction | Operation |
|:------:|-------------|-----------|
| 0x10 | LI sp, imm | sp = imm8 |
| 0x12 | LI pl, imm | pl = imm8 |
| 0x13 | LI ph, imm | ph = imm8 |
| 0x14 | LI t0, imm | t0 = imm8 |
| 0x15 | LI pg, imm | pg = imm8 |
| 0x24 | MOV rd, a0 | reg[operand] = a0 |
| 0x25 | MOV a0, rs | a0 = reg[operand] |
| 0x26 | LB [sp+imm] | a0 = mem[{$30, sp+imm8}] |
| 0x27 | SB [sp+imm] | mem[{$30, sp+imm8}] = a0 |
| 0x28 | LB [zp+imm] | a0 = mem[{$00, imm8}] |
| 0x29 | SB [zp+imm] | mem[{$00, imm8}] = a0 |
| 0x2A | LB [pg:imm] | a0 = mem[{pg, imm8}] |
| 0x2B | SB [pg:imm] | mem[{pg, imm8}] = a0 |
| — | ADD c0/c1/cn/ch | Use constant generator (0/1/$FF/$80) |

## Schematic

```
Register Write Select (wr_sel[2:0]):
  Decoded from opcode for LI: opcode[2:0] + 1
  For MOV rd,a0: operand[2:0]
  For POP: operand[2:0]
  Default: 2 (a0)

  wr_sel → selects which 74HC574 gets clocked:
    1=sp, 2=a0, 3=pl, 4=ph, 5=t0, 6=pg

Address Mux (extended):
  addr_sel=0: {PC_hi, PC_lo}         ← fetch
  addr_sel=1: {ph, pl}               ← pointer
  addr_sel=2: {$30, SP}              ← stack (POP/RET)
  addr_sel=3: {$00, operand}         ← zero-page
  addr_sel=4: {pg, operand}          ← page-relative
  addr_sel=6: {$30, SP + operand}    ← sp+imm
  addr_sel=7: {$30, SP - 1}          ← stack pre-dec (PUSH)

SP+imm adder:
  Use spare 74HC283 (or half of existing one during S2)
  addr_lo = SP + operand byte

Constant Generator (in register read logic):
  When rd_sel=0 (register x0):
    operand[4:3]=00 → read $00
    operand[4:3]=01 → read $01
    operand[4:3]=10 → read $FF
    operand[4:3]=11 → read $80
```

## Procedure

1. Add wr_sel decode: generate 3-bit register select from opcode.
   - LI: wr_sel = opcode[2:0] + 1
   - MOV rd,a0: wr_sel = operand[2:0]
   - Default: wr_sel = 2 (a0)
2. Route wr_sel to individual register clock enables (gate each 574's CLK).
3. Add zero-page address mode: wire $00 to addr_hi, operand to addr_lo when addr_sel=3.
4. Add page-relative mode: wire pg register to addr_hi, operand to addr_lo when addr_sel=4.
5. Add sp+imm mode: add small adder (SP + operand) → addr_lo, $30 → addr_hi when addr_sel=6.
6. Add constant generator: mux on register read port, outputs 0/1/$FF/$80 when reading x0.
7. Add MOV path: for MOV a0,rs use ALU PASS_B with reg read; for MOV rd,a0 use ALU pass-through.

## Test Procedure

| Test | Program | Expected |
|:----:|---------|----------|
| 1 | LI sp,$F0 / LI t0,$BB / LI pg,$CC / HLT | sp=$F0, t0=$BB, pg=$CC |
| 2 | LI a0,$AB / MOV t0,a0 / LI a0,0 / MOV a0,t0 / HLT | a0 = $AB |
| 3 | LI a0,$DE / SB [zp+$42] / LI a0,0 / LB [zp+$42] / HLT | a0 = $DE |
| 4 | LI sp,$F0 / LI a0,$99 / SB [sp+2] / LI a0,0 / LB [sp+2] / HLT | a0 = $99 |
| 5 | LI pg,$50 / LI a0,$77 / SB [pg:$10] / LI a0,0 / LB [pg:$10] / HLT | a0 = $77 |
| 6 | LI a0,$10 / ADD c1 / HLT | a0 = $11 (added constant 1) |
| 7 | LI a0,$10 / ADD cn / HLT | a0 = $0F (added constant $FF = -1) |

## Checkoff

- [ ] LI loads correct register (sp, pl, ph, t0, pg)
- [ ] MOV copies between registers correctly
- [ ] Zero-page LB/SB: read/write at {$00, imm}
- [ ] SP+imm LB/SB: read/write at {$30, sp+imm}
- [ ] Page-relative LB/SB: read/write at {pg, imm}
- [ ] Constant generator: ADD c0=0, c1=1, cn=$FF, ch=$80
- [ ] No register corruption (writing to t0 doesn't affect a0)

## Notes
- After this lab: all 6 LI variants + 2 MOV + 6 LB/SB modes + constant gen = **~50 instructions total**.
- The sp+imm adder can share the ALU's 74HC283 during the memory-access state (ALU isn't computing then).
- Pointer ops (INC16, DEC16, ADD16) also become available since pl/ph can now be loaded.

---

## Thai Version

---

# แลป 11: Addressing Modes และ Register Routing

---

## เป้าหมาย

เพิ่มโหมดการเข้าถึงหน่วยความจำทั้งหมด + ให้ LI โหลดได้ทุก register + MOV + constant generator

---

## ความรู้พื้นฐาน

**ปัญหา:** หลัง Lab 10 CPU โหลดค่าได้แค่ a0 และเข้าถึง RAM ได้แค่ผ่าน pointer

**ต้องเพิ่ม:**
- LI ไปทุก register (sp, pl, ph, t0, pg)
- MOV ย้ายค่าระหว่าง register
- Zero-page: อ่าน/เขียน address {$00, imm} — ตัวแปร global เร็ว
- SP+imm: อ่าน/เขียน address {$30, sp+imm} — ตัวแปร local
- Page-relative: อ่าน/เขียน address {pg, imm} — เข้าถึงหน้าต่างๆ
- Constant generator: register x0 ให้ค่า 0, 1, $FF, $80 อัตโนมัติ

---

## อุปกรณ์เพิ่มเติม

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC157 | 1 | เลือก register ที่จะเขียน (wr_sel) |
| (ต่อสายเพิ่ม) | — | address mux input ใหม่ |

---

## ขั้นตอนต่อวงจร

1. เพิ่ม wr_sel decode: เลือกว่าจะเขียน register ไหน จาก opcode
2. ต่อ wr_sel ไปควบคุม CLK ของแต่ละ 74HC574
3. เพิ่ม zero-page mode: addr = {$00, operand}
4. เพิ่ม page-relative mode: addr = {pg, operand}
5. เพิ่ม sp+imm mode: addr = {$30, SP + operand} (ใช้ adder)
6. เพิ่ม constant generator: เมื่ออ่าน register 0 ให้ค่า 0/1/$FF/$80
7. เพิ่ม MOV path: ส่งค่าระหว่าง register ผ่าน ALU

---

## ทดสอบ

| ขั้น | โปรแกรม | ผลที่ถูกต้อง |
|:----:|---------|-------------|
| 1 | LI sp,$F0 / LI t0,$BB / LI pg,$CC | sp=$F0, t0=$BB, pg=$CC |
| 2 | LI a0,$AB / MOV t0,a0 / MOV a0,t0 | a0 = $AB (ย้ายไปกลับ) |
| 3 | SB [zp+$42] / LB [zp+$42] | อ่านกลับได้ค่าเดิม |
| 4 | SB [sp+2] / LB [sp+2] | อ่านกลับได้ค่าเดิม |
| 5 | SB [pg:$10] / LB [pg:$10] | อ่านกลับได้ค่าเดิม |
| 6 | LI a0,$10 / ADD c1 | a0 = $11 (บวกค่าคงที่ 1) |

---

## เช็คลิสต์ผ่าน

- [ ] LI โหลดถูก register (sp, pl, ph, t0, pg)
- [ ] MOV ย้ายค่าถูกต้อง
- [ ] Zero-page เขียน/อ่านได้
- [ ] SP+imm เขียน/อ่านได้
- [ ] Page-relative เขียน/อ่านได้
- [ ] Constant generator ให้ค่า 0, 1, $FF, $80 ถูกต้อง
- [ ] เขียน register หนึ่งไม่กระทบ register อื่น

---

## หมายเหตุ

- หลัง Lab นี้: ~50 คำสั่งทำงานได้
- INC16/DEC16/ADD16 ก็ใช้ได้แล้ว (เพราะ pl/ph โหลดค่าได้)
- Lab สุดท้าย (Lab 12) จะเพิ่ม interrupt และ skip ให้ครบ 68 คำสั่ง
