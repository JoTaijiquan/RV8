# RV8-W — Understand by Module (How Chips Become a CPU)

**25 logic chips. No microcode. Instruction byte directly controls hardware.**

---

## How RV8-W differs from RV8:

| | RV8 | RV8-W |
|--|:---:|:---:|
| Control | Flash microcode (lookup table) | **Instruction bits = control wires** |
| Steps/instruction | 4-8 (sequenced) | **2 (fetch + execute)** |
| ALU A input | From IBUS (any register) | **Hardwired from AC (always)** |
| Registers | 8 (all equal) | 8 (AC special + 7 general) |
| Step counter | Needed (U26) | **Not needed** |
| Microcode ROM | 2× Flash | **None** |

---

## 5 Modules (RV8-W is simpler than RV8!)

```
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐           │
│  │ Module 1 │   │ Module 2 │   │ Module 3 │           │
│  │    AC    │   │   ALU    │   │    PC    │           │
│  │(accumulator)│ │  (math)  │   │(counter) │           │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘           │
│       │               │               │                 │
│  ALU_A (hardwired)    │          ADDRESS BUS            │
│       │               │               │                 │
│  ═══════════════ IBUS (internal 8-bit) ═══════════════  │
│       ▲               ▲               ▲                 │
│       │               │               │                 │
│  ┌────┴─────┐   ┌────┴─────┐   ┌────┴─────┐          │
│  │ Module 4 │   │ Module 5 │   │ Module 6 │          │
│  │REGISTERS │   │ MEMORY   │   │ CONTROL  │          │
│  │ r1-r7    │   │(ROM+RAM) │   │(IR_HIGH) │          │
│  └──────────┘   └──────────┘   └──────────┘          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Module 1: AC — The Accumulator (U1)

### Chip: 1× 74HC574

### Why special?
AC is the ONLY register whose output goes to ALU A. It's **hardwired** — always connected, no /OE switching needed.

### Connections:
```
Q outputs → ALU A inputs (direct wire, always)
Q outputs → U25 (541 buffer) → IBUS (only when AC_TO_BUS=LOW)
D inputs  ← IBUS (receives ALU result or memory data)
CLK       ← AC_WR signal (from IR_HIGH control byte)
```

### Why it needs a buffer (U25, 74HC541):
AC Q outputs go to ALU A (always). But sometimes AC value needs to go on IBUS (for MV rd,a0 or SB). Can't use AC's /OE for this (would disconnect from ALU A too!). So U25 buffer copies AC → IBUS when needed.

### ⚠️ ISSUE CHECK:
**Q: Can AC D inputs come from IBUS while Q outputs drive ALU A?**
A: Yes! 574 D inputs and Q outputs are independent. D waits for CLK edge. Q drives continuously. No conflict. ✅

---

## Module 2: ALU (U11-U14) — The Calculator

### Chips: 2× 74HC283 (adder) + 2× 74HC86 (XOR)

### How it works:
```
ALU A ← AC (hardwired, always)
ALU B ← IBUS (from register or operand, via XOR for SUB)
Result → IBUS (for AC to latch, or for register to latch)
```

### ⚠️ ISSUE CHECK:
**Q: ALU result goes WHERE?**
The adder output is combinational (always computing). It needs to go onto IBUS so AC (or other register) can latch it.

**Problem**: If a register is driving IBUS (as ALU B source) AND ALU result also drives IBUS → **conflict!**

**Fix**: ALU result needs a **latch + tri-state buffer** to drive IBUS only when needed. This is NOT in the current 25-chip design!

**Missing chip**: Need 1× 74HC574 (ALU result latch with /OE) to hold result and drive IBUS on command.

**Revised: 26 logic chips** (add U26 = ALU result latch).

OR: Route ALU result directly to AC D inputs (not through IBUS). Then AC always gets ALU result. For MV rd,a0: AC→buffer→IBUS→register. This works WITHOUT extra latch if AC D inputs are hardwired from adder output (not from IBUS).

**Let me check**: If AC.D ← adder output (always), then:
- ADDI: adder computes AC+imm → AC.D = result → CLK pulse → AC updates ✅
- LB: memory data on IBUS → but AC.D is wired to adder, not IBUS! ❌

**Problem**: LB needs memory data → AC. But AC.D is hardwired to adder output.

**Fix options**:
1. Add mux on AC.D input (adder vs IBUS) → +2× 74HC157 = +2 chips
2. Route memory data through adder: data + 0 = data (PASS) → AC gets it ✅ **Zero extra chips!**

For LB: set ALU B = memory data (from IBUS), ALU A = 0 (force AC=0 first? No...)

Actually: ALU A = AC (current value). We want result = memory data, not AC + data.

**Real fix**: ALU needs a PASS mode (result = B, ignore A). The XOR+adder can't do this without extra logic.

**OR**: Accept that LB requires 2 steps:
```
Step 1: LI a0, 0      (clear AC)
Step 2: ADD a0, a0, mem_data  (0 + data = data → AC)
```
But that's 2 instructions for one load — slow and ugly.

---

## ❌ DESIGN ISSUE FOUND

**RV8-W cannot do LB (load byte from memory) in a clean way** because:
1. AC.D must come from IBUS (for LB) OR from adder (for ALU ops)
2. These are different sources → need a mux
3. Mux costs +2 chips (74HC157 ×2 for 8-bit)

**Revised honest chip count: 27 logic chips** (same as RV8!)

| Add | Why | Chips |
|-----|-----|:-----:|
| 74HC157 ×2 | AC D-input mux (adder vs IBUS) | +2 |
| **Total** | | **27** |

---

## Module 3: PC (U15-U18) — The Counter

### Chips: 4× 74HC161

### Why 161 (not 574 like RV8)?
RV8-W has **no microcode** to compute PC+1. So PC must auto-increment itself. 74HC161 is a counter — it increments every clock automatically. No ALU needed!

### ⚠️ ISSUE CHECK:
**Q: How does PC disconnect for data access?**
74HC161 has NO /OE. Outputs always drive.

**Fix**: U21 (74HC541) buffers PC high byte with /OE. For PC low byte, U24 (74HC157) mux selects PC vs register.

**Q: How does branch work (load new PC value)?**
74HC161 has /LD pin — parallel load from D inputs. Branch target goes to D inputs, pulse /LD → PC jumps. ✅

**Q: Where does branch target come from?**
From operand (sign-extended offset added to PC). But... who computes PC+offset? The ALU is busy with AC!

**Problem**: Branch needs PC+offset. ALU A is hardwired to AC (not PC). Can't compute PC+offset without changing ALU A source.

**Fix options**:
1. Add mux on ALU A (AC vs PC) → +2 chips
2. Use separate adder for PC+offset → +2 chips
3. Accept: branch offset loaded directly into PC (absolute jump only, no relative branch)

Option 3 is simplest: `JMP addr` (absolute) works. `BEQ offset` (relative) doesn't without extra hardware.

**This limits the ISA**: no relative branches. Must use absolute jumps. BASIC still works (just less efficient).

---

## Module 4: Registers r1-r7 (U2-U8)

### Chips: 7× 74HC574

### Same as RV8 — /OE for IBUS drive, CLK for write.
No issues here. ✅

---

## Module 5: Memory Interface (U21, U22, U24)

### Chips: 74HC541 (PC buffer) + 74HC245 (bus bridge) + 74HC157 (addr mux)

### Works same as RV8. ✅

---

## Module 6: Control (U9-U10, U19-U20, U23)

### Chips: 2× 74HC574 (IR) + 2× 74HC138 (decode) + 1× 74HC74 (flags+state)

### The key difference: NO MICROCODE!
U9 (IR_HIGH) outputs directly drive hardware:
```
IR_HIGH bit 6-4 → ALU op (to XOR chips)
IR_HIGH bit 3   → immediate mode
IR_HIGH bit 2   → AC write enable
IR_HIGH bit 1   → memory access
IR_HIGH bit 0   → branch
```

### ⚠️ ISSUE CHECK:
**Q: 8 bits enough to control everything?**
Need: ALU_OP(3) + IMM(1) + AC_WR(1) + MEM(1) + BRANCH(1) + REG_SEL(3) = 10 bits minimum.

Only 8 bits available in control byte. **2 bits short!**

**Fix**: Use operand byte bits for register select (already planned: operand[7:5]=rs). So control byte only needs 7 bits. Fits! ✅

---

## SUMMARY OF ISSUES FOUND:

| Issue | Impact | Fix | Extra chips |
|-------|--------|-----|:-----------:|
| AC D-input needs mux (adder vs IBUS) | Can't do LB without it | +2× 74HC157 | +2 |
| No relative branch (PC+offset) | Must use absolute JMP | Accept limitation | 0 |
| ALU result → IBUS conflict | Can't write result to other registers | Route via AC+buffer | 0 |

**Honest RV8-W: 27 logic chips** (same as RV8, after fixing LB issue).

---

## Revised comparison:

| | RV8 | RV8-W (honest) |
|--|:---:|:---:|
| Logic chips | 27 | **27** (same!) |
| Speed | 1.25 MIPS | **2.5 MIPS** (still faster) |
| Microcode | Yes (2× Flash) | **No** |
| Step counter | Yes | **No** |
| Relative branch | ✅ | ❌ (absolute only) |
| AND/OR/XOR | ✅ | ❌ (adder only) |
| Complexity | Higher (microcode table) | Lower (direct control) |

**RV8-W is still faster (2× fewer cycles) but loses relative branch and logic ops.**

---

# ภาษาไทย — RV8-W ทำงานอย่างไร

## ความแตกต่างจาก RV8:

```
RV8:   สมอง (Flash) สั่งทุกอย่าง ทีละขั้น (4-8 ขั้นต่อคำสั่ง)
RV8-W: คำสั่งเอง สั่งตรง ไม่ต้องมีสมอง (2 ขั้นต่อคำสั่ง)
```

## ปัญหาที่พบ:

1. **AC รับข้อมูลจากไหน?** — ต้องมี mux เลือก (จาก ALU หรือจาก memory) → +2 ชิป
2. **กระโดดแบบ relative ไม่ได้** — เพราะ ALU ผูกกับ AC ไม่ใช่ PC
3. **AND/OR/XOR ทำไม่ได้** — มีแค่วงจรบวก

## สรุป: RV8-W ใช้ชิปเท่า RV8 (27 ตัว) แต่เร็วกว่า 2 เท่า แลกกับความสามารถที่น้อยกว่า
