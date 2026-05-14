# Lab 12: Interrupts, Skip, and Full State Machine

## Objective
Add NMI/IRQ interrupt handling, TRAP/RTI, conditional skip instructions, and the complete state machine. After this lab, all 68 instructions work.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC74 | 1 | NMI edge detect + interrupt pending flip-flop |
| (wiring changes) | — | Vector fetch logic, skip flag, IE flag |

## Concept

The final pieces of the RV8:
1. **Interrupts**: external events (NMI, IRQ) cause the CPU to jump to a handler
2. **TRAP**: software interrupt (push state, jump to vector)
3. **RTI**: return from interrupt (restore state)
4. **Skip**: conditionally skip the next instruction (1-bit flag)
5. **Full state machine**: all 7 states for every instruction timing

```
Normal:     S0 → S1 → S0 (2-cycle: fetch + execute)
Memory:     S0 → S1 → S2 → S0 (3-cycle: + memory access)
JAL:        S0 → S1 → S2 → S3 → S4 → S0 (5-cycle)
TRAP:       S0 → S1 → S2 → S3 → S4 → S5 → S6 → S0 (7-cycle)
RTI:        S0 → S1 → S2 → S3 → S4 → S0 (5-cycle)
Interrupt:  (from S1) → S5 → S6 → S0 (vector fetch)
```

## New Instructions Enabled

| Opcode | Instruction | Operation |
|:------:|-------------|-----------|
| 0x37 | SKIPZ | Skip next if Z=1 |
| 0x38 | SKIPNZ | Skip next if Z=0 |
| 0x39 | SKIPC | Skip next if C=1 |
| 0x3A | SKIPNC | Skip next if C=0 |
| 0xF2 | EI | Enable interrupts (IE=1) |
| 0xF3 | DI | Disable interrupts (IE=0) |
| 0xF4 | RTI | Pop flags, pop PCL, pop PCH |
| 0xF5 | TRAP imm | Push PCH, PCL, flags; PC = vector[$FFF6] |
| 0xFE | NOP | No operation |
| 0xFF | HLT | Halt (wake on interrupt) |

Plus: NMI (vector $FFFA) and IRQ (vector $FFFE) hardware interrupts.

## Schematic

```
NMI Edge Detect:
  NMI_pin → 74HC74 (D=0, CLK=falling edge of NMI)
  Q = nmi_pending
  Clear when interrupt acknowledged

IRQ Level Detect:
  IRQ_pin (active low) AND IE flag = irq_request

Interrupt Priority:
  NMI > IRQ (NMI always wins)

Vector Fetch (states S5→S6):
  S5: addr = vector_addr, read low byte → store in ir_opcode
  S6: addr = vector_addr+1, read high byte → PC = {high, low}

  Vector addresses:
    RESET: $FFFC
    NMI:   $FFFA
    IRQ:   $FFFE
    TRAP:  $FFF6

Skip Flag:
  1-bit register, set by SKIPZ/SKIPNZ/SKIPC/SKIPNC when condition true
  When skip_flag=1: next instruction executes as NOP (no side effects)
  Cleared after one instruction skipped

IE Flag:
  Part of flags register
  EI sets it, DI clears it
  Interrupt entry clears it (prevent nested interrupts)
  RTI restores it from stack
```

## Procedure

1. Add NMI edge detector: 74HC74 with D=VCC, CLK=NMI_pin (falling edge), /CLR=int_ack.
2. Add IRQ logic: IRQ_pin AND IE_flag = irq_request.
3. Add interrupt priority: nmi_pending OR (irq_request AND !nmi) = int_request.
4. Add vector_addr register: latches $FFFC (reset), $FFFA (NMI), $FFFE (IRQ), $FFF6 (TRAP).
5. Add S5/S6 states to state machine for vector fetch.
6. Add skip flag: 1-bit FF, set by skip instructions, cleared after one cycle.
7. Add IE flag to flags register (bit in the flags byte for TRAP/RTI save/restore).
8. Add TRAP sequence: S2=push PCH, S3=push PCL, S4=push flags, S5/S6=vector fetch.
9. Add RTI sequence: S2=pop flags, S3=pop PCL, S4=pop PCH+load PC.
10. Add HLT: gate clock or loop in halt state until interrupt.
11. Wire NMI and IRQ pins to external connectors.

## Test Procedure

| Test | Program | Expected |
|:----:|---------|----------|
| 1 | LI a0,0 / CMPI 0 / SKIPZ / LI a0,$BB / HLT | a0=$00 (LI $BB skipped) |
| 2 | LI a0,5 / CMPI 5 / SKIPNZ / LI a0,$CC / HLT | a0=$CC (not skipped) |
| 3 | SEC / SKIPC / LI a0,$BB / LI a0,$22 / HLT | a0=$22 (LI $BB skipped) |
| 4 | EI / HLT / (fire IRQ) / ISR: LI a0,$EE / HLT | a0=$EE (IRQ woke CPU) |
| 5 | (pulse NMI) / NMI handler: LI a0,$DD / HLT | a0=$DD (NMI handled) |
| 6 | SEC / TRAP / (handler: CLC / RTI) / HLT | C=1 restored by RTI |
| 7 | EI / DI / (fire IRQ) / HLT | IRQ ignored (IE=0) |
| 8 | NOP / NOP / LI a0,$42 / HLT | a0=$42 (NOPs do nothing) |

## Checkoff

- [ ] SKIPZ/SKIPNZ: skip works when condition true, doesn't skip when false
- [ ] SKIPC/SKIPNC: same for carry flag
- [ ] EI/DI: enable/disable interrupts
- [ ] IRQ: wakes from HLT, jumps to vector, executes handler
- [ ] NMI: edge-triggered, non-maskable, jumps to vector
- [ ] TRAP: pushes PC+flags, jumps to trap vector
- [ ] RTI: restores flags + PC, returns to caller
- [ ] HLT: CPU stops, wakes on interrupt
- [ ] NOP: no effect on any state
- [ ] All 68 instructions verified (run full testbench)

## Final Verification

Program ROM with the full test suite (same as `tb/tb_rv8_cpu.v` test vectors):
```
Run all 69 test assertions in hardware using the trainer board serial monitor.
Each test: load program, run, check a0 value via LED or serial readback.
```

## Congratulations! 🎉

All **68 instructions** of the RV8 ISA are now operational. Your CPU can:
- Perform all arithmetic and logic operations
- Access memory via 5 different addressing modes
- Call and return from subroutines
- Handle hardware interrupts (NMI + IRQ)
- Execute software traps with full state save/restore
- Conditionally skip instructions
- Run a BASIC interpreter

**Total chip count: 27** (23 CPU + ROM + RAM + buffer + decode)

---

## Thai Version

---

# แลป 12: Interrupt, Skip, และ State Machine เต็มรูปแบบ

---

## เป้าหมาย

เพิ่ม interrupt (NMI/IRQ), TRAP/RTI, คำสั่ง skip, และ state machine ครบ — หลัง Lab นี้ **ครบ 68 คำสั่ง!**

---

## ความรู้พื้นฐาน

**Interrupt (ขัดจังหวะ)** = สัญญาณจากภายนอกที่บังคับให้ CPU หยุดงานปัจจุบัน ไปทำงานเร่งด่วน แล้วกลับมาทำต่อ
- NMI = ขัดจังหวะฉุกเฉิน (บังคับ ห้ามปิด)
- IRQ = ขัดจังหวะทั่วไป (ปิดได้ด้วย DI)

**TRAP** = interrupt ที่โปรแกรมเรียกเอง (เหมือนกดปุ่มฉุกเฉินเอง)

**RTI** = กลับจาก interrupt (คืนสถานะเดิมทั้งหมด)

**Skip** = ข้ามคำสั่งถัดไป 1 คำสั่ง ถ้าเงื่อนไขเป็นจริง

**Vector** = ที่อยู่ของ handler เก็บไว้ในตำแหน่งตายตัว:
- RESET: $FFFC, NMI: $FFFA, IRQ: $FFFE, TRAP: $FFF6

---

## อุปกรณ์เพิ่มเติม

| อุปกรณ์ | จำนวน | ทำหน้าที่อะไร |
|---------|:------:|--------------|
| 74HC74 | 1 | ตรวจจับ NMI (edge detect) + pending flag |

---

## ขั้นตอนต่อวงจร

1. เพิ่ม NMI edge detector: 74HC74 จับขอบขาลงของ NMI pin
2. เพิ่ม IRQ logic: IRQ pin AND IE flag = มี interrupt request
3. เพิ่ม vector_addr register: เก็บ address ของ vector ที่จะอ่าน
4. เพิ่ม state S5/S6: อ่าน vector low byte แล้ว high byte → โหลด PC
5. เพิ่ม skip flag: 1 บิต ตั้งโดย SKIPZ/SKIPNZ/SKIPC/SKIPNC ล้างหลังข้าม 1 คำสั่ง
6. เพิ่ม IE flag ใน flags register (EI ตั้ง, DI ล้าง, RTI คืนค่า)
7. เพิ่ม TRAP sequence: push PCH → push PCL → push flags → vector fetch
8. เพิ่ม RTI sequence: pop flags → pop PCL → pop PCH → load PC
9. เพิ่ม HLT: หยุด CPU จนกว่าจะมี interrupt
10. ต่อขา NMI และ IRQ ออกไปที่ connector ภายนอก

---

## ทดสอบ

| ขั้น | โปรแกรม | ผลที่ถูกต้อง |
|:----:|---------|-------------|
| 1 | CMPI 0 / SKIPZ / LI a0,$BB | a0=0 (ข้าม LI เพราะ Z=1) |
| 2 | SEC / SKIPC / LI a0,$BB / LI a0,$22 | a0=$22 (ข้าม LI $BB) |
| 3 | EI / HLT / (ยิง IRQ) / handler: LI a0,$EE | a0=$EE (IRQ ปลุก CPU) |
| 4 | (pulse NMI) / handler: LI a0,$DD | a0=$DD (NMI ทำงาน) |
| 5 | SEC / TRAP / (handler: CLC / RTI) | C=1 คืนค่าโดย RTI |
| 6 | DI / (ยิง IRQ) | IRQ ถูกเพิกเฉย (IE=0) |
| 7 | NOP / NOP / LI a0,$42 | a0=$42 (NOP ไม่ทำอะไร) |

---

## เช็คลิสต์ผ่าน

- [ ] SKIPZ/SKIPNZ: ข้ามเมื่อเงื่อนไขจริง ไม่ข้ามเมื่อเท็จ
- [ ] SKIPC/SKIPNC: เหมือนกันสำหรับ Carry
- [ ] EI/DI: เปิด/ปิด interrupt
- [ ] IRQ: ปลุก CPU จาก HLT กระโดดไป handler
- [ ] NMI: ทำงานเสมอ (ปิดไม่ได้)
- [ ] TRAP: push PC+flags แล้วกระโดดไป vector
- [ ] RTI: คืน flags + PC กลับมาทำงานต่อ
- [ ] HLT: CPU หยุด ปลุกด้วย interrupt
- [ ] NOP: ไม่มีผลใดๆ
- [ ] **ครบ 68 คำสั่ง** (รัน test suite ทั้งหมดผ่าน)

---

## 🎉 ยินดีด้วย! CPU ครบสมบูรณ์!

หลัง Lab 12 RV8 CPU ของคุณทำได้ทุกอย่าง:
- คำนวณทุกแบบ (บวก ลบ AND OR XOR เลื่อนบิต หมุนบิต)
- เข้าถึงหน่วยความจำ 5 โหมด
- เรียกฟังก์ชันซ้อนกันได้
- รับ interrupt จากภายนอก (NMI + IRQ)
- TRAP + RTI สำหรับ system call
- ข้ามคำสั่งแบบมีเงื่อนไข
- **พร้อมรัน BASIC interpreter!**

**ชิปทั้งหมด: 26 ตัว** (CPU 23 + address decode + ROM + RAM)
