# RV8-S — Understand by Module (How Chips Become a CPU)

**20 logic chips. Serial ALU. Same ISA as RV8. Fewest chips.**

---

## How RV8-S differs from RV8:

| | RV8 | RV8-S |
|--|:---:|:---:|
| Registers | 74HC574 (parallel 8-bit) | **74HC595 (shift register, serial)** |
| ALU | 74HC283 (8-bit parallel adder) | **2 gates (1-bit full adder)** |
| Data transfer | 8 bits at once | **1 bit at a time (8 clocks)** |
| Chips for ALU | 4 (283×2 + 86×2) | **3 (74+86+08)** |
| Chips for registers | 8 (574×8) | **8 (595×8)** |
| Speed | 1.25 MIPS | **1.0 MIPS** |
| Fetch | Parallel (same) | **Parallel (same)** |

---

## 4 Modules

```
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  ┌──────────────────────────────────────────────┐       │
│  │ Module 1: SERIAL CHAIN (SBUS, 1-bit)         │       │
│  │ U1-U8 (595) → U12 (XOR) → U13 (AND) → U11  │       │
│  │ [registers]   [sum]        [carry]    [carry FF]     │
│  └──────────────────────────────────────────────┘       │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐                    │
│  │ Module 2:    │  │ Module 3:    │                    │
│  │ FETCH (IBUS) │  │ PC + MEMORY  │                    │
│  │ U9,U10,U22   │  │ U14-U17,ROM,RAM                  │
│  └──────────────┘  └──────────────┘                    │
│                                                          │
│  ┌──────────────────────────────────────────────┐       │
│  │ Module 4: CONTROL (U18 mux + U19 Flash)      │       │
│  └──────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

---

## Module 1: Serial Chain (U1-U8, U11-U13) — "the shift-and-add machine"

### Chips:
- 8× 74HC595 (shift register) = U1-U8
- 1× 74HC74 (carry flip-flop) = U11
- 1× 74HC86 (XOR) = U12
- 1× 74HC08 (AND) = U13

### Why 74HC595 (not 574)?
595 is a **shift register**: data moves through it 1 bit per clock. This lets us do ALU operations **serially** — process 1 bit at a time, 8 clocks for a full byte.

574 is parallel (all 8 bits at once) — needs 8-bit adder (2 chips).
595 is serial (1 bit at a time) — needs 1-bit adder (2 gates). **Saves 2 chips!**

### How 1-bit ALU works:
```
Clock 1: bit0 of register A + bit0 of register B + carry_in → result bit0, new carry
Clock 2: bit1 of A + bit1 of B + carry → result bit1, new carry
...
Clock 8: bit7 of A + bit7 of B + carry → result bit7, final carry
```

### The full adder (2 gates + 1 flip-flop):
```
SUM  = A XOR B XOR Carry_in     (U12, 1 XOR gate)
CARRY_OUT = (A AND B) OR (Carry AND (A XOR B))  (U13 + diode-OR)
```

U11 (74HC74) stores the carry between bits. Resets to 0 at start of each operation (or 1 for SUB).

### ⚠️ ISSUE CHECK:

**Q: How does register select work?**
All 8 registers (595) have QH' (serial output). Need to pick which one feeds the ALU.

**Fix**: U18 (74HC151, 8:1 mux) selects one QH' → ALU input B. ✅

**Q: Where does ALU result go?**
Back into the destination register's SER (serial input) pin. Microcode selects which register's SER gets the result.

**Problem**: 595 SER input is shared — all registers shift on same SRCLK. If all shift simultaneously, they all get the result!

**Fix**: Only the destination register should shift. Others should hold. But 595 has only ONE shift clock for all...

**Real fix options**:
1. Gate each register's SRCLK individually (need 8 AND gates = 2× 74HC08) → +2 chips
2. Use 595's /OE to disconnect non-destination outputs (doesn't help — shifting still happens)
3. Accept: ALL registers shift simultaneously. Non-destination registers shift their own data back in (recirculate). Only destination gets ALU result on SER.

**Option 3 works!** Wire each register's QH' back to its own SER (recirculate). Only the selected destination gets ALU result instead. Need a mux per register... that's 8 muxes = too many chips.

**Simpler**: Use microcode to sequence:
1. Shift source register out (8 clocks) → into temp
2. Shift result into destination (8 clocks)
3. Other registers don't shift (their SRCLK gated off)

**Need**: Individual SRCLK gating. Use U18 (138 decoder) to enable only 1 register's SRCLK at a time.

**Revised**: U18 = 74HC138 (not 151). Outputs gate individual SRCLKs via AND with master shift clock.

But 138 gives active-LOW outputs. Need AND gates: `reg_SRCLK = master_SRCLK AND /Y_n`. That's 8 AND gates = 2× 74HC08.

**+2 chips! Revised: 22 logic chips.**

---

## Module 2: Fetch (U9-U10, U22) — Parallel, same as RV8

### Chips: 2× 74HC574 (IR) + 1× 74HC245 (bus buffer)

### How fetch works:
```
PC → ROM address → ROM data → U22 (245) → IBUS → U9 (IR opcode) latches
PC+1 → ROM → U22 → IBUS → U10 (IR operand) latches
```

Fetch is **parallel** (8 bits at once via IBUS). Only ALU is serial. This is why RV8-S is faster than pure-serial designs.

### ⚠️ ISSUE CHECK:

**Q: How does memory data get INTO a 595 register (for LB instruction)?**
595 has no parallel load! Can only shift in serially.

**Fix**: For LB, microcode must:
1. Read memory byte onto IBUS (parallel, via U22)
2. Shift it into destination register 1 bit at a time

But IBUS is 8-bit parallel. 595 SER input is 1-bit. Need parallel-to-serial conversion.

**Fix**: Use U18 (151 mux) to select IBUS bits one at a time:
```
Clock 1: mux selects IBUS[0] → SER → shift
Clock 2: mux selects IBUS[1] → SER → shift
...
Clock 8: mux selects IBUS[7] → SER → shift
```

U18 address changes each clock (from step counter in microcode). **Works! No extra chip.** ✅

**Q: How does register value get ONTO IBUS (for SB instruction)?**
595 has parallel outputs (QA-QH). These can drive IBUS directly (via /OE or buffer).

But all 8 registers have parallel outputs always active... **bus conflict!**

**Fix**: 595 has /OE pin! Use decoder to enable only one register's parallel output onto IBUS. Need another 138 decoder.

**+1 chip (U_extra = 74HC138 for parallel output select). Revised: 23 logic chips.**

---

## Module 3: PC + Memory (U14-U17, ROM, RAM)

### Chips: 4× 74HC161 (PC counter) + ROM + RAM

Same as RV8. PC auto-increments, drives ROM address. No issues. ✅

### ⚠️ ISSUE CHECK:

**Q: How does data access work (LB/SB address)?**
Need register value on address bus. Register parallel outputs → address bus.

But PC (161) always drives address bus (no /OE)!

**Same fix as RV8**: Need 74HC541 buffer on PC high byte + 74HC157 mux on low byte. **+2 chips.**

**Revised: 25 logic chips.**

---

## Module 4: Control (U19 Flash)

### Chip: 1× SST39SF010A (microcode Flash)

Same concept as RV8 — Flash sequences all operations. But more steps per instruction (serial ALU takes 8 extra clocks).

### ⚠️ ISSUE CHECK:

**Q: 8 Flash output bits enough?**
Need to control: register SRCLK select(3), ALU_SUB(1), mux address(3), IR_CLK(1), OPR_CLK(1), PC_INC(1), BUF_OE(1), parallel_OE_select(3)...

That's ~14 bits. **8 not enough!**

**Fix**: Same as RV8 — need 2nd Flash (or wider ROM). **+1 chip.**

**Revised: 26 logic chips.**

---

## SUMMARY OF ISSUES FOUND:

| Issue | Fix | Extra chips |
|-------|-----|:-----------:|
| Individual SRCLK gating (8 registers) | 74HC138 decoder + 2× 74HC08 (AND gates) | +3 |
| Parallel output select (for SB/address) | 74HC138 decoder | +1 |
| PC buffer + address mux | 74HC541 + 74HC157 | +2 |
| Flash output width (need 14+ bits) | 2nd Flash | +1 |
| **Total extra** | | **+7** |

---

## HONEST CHIP COUNT:

| Function | Chips |
|----------|:-----:|
| Registers (595×8) | 8 |
| ALU (74+86+08) | 3 |
| IR (574×2) | 2 |
| PC (161×4) | 4 |
| Bus buffer (245) | 1 |
| Register SRCLK decode (138) | 1 |
| SRCLK gating (08×2) | 2 |
| Parallel output decode (138) | 1 |
| PC buffer (541) | 1 |
| Address mux (157) | 1 |
| Microcode Flash ×2 | 2 |
| **Total logic** | **26** |
| + ROM + RAM | +2 |
| **Grand total** | **28** |

---

## Revised comparison (ALL HONEST):

| | RV8 | RV8-W | RV8-S |
|--|:---:|:---:|:---:|
| Logic chips | 27 | 27 | **26** |
| Total | 29 | 29 | **28** |
| MIPS | 1.25 | 2.5 | **~0.5** |
| AND/OR/XOR | ✅ | ❌ | ✅ (microcode) |
| Relative branch | ✅ | ❌ | ✅ |
| Wiring complexity | Medium | Medium | **High** (serial chain) |
| Best for | Flexibility | Speed | ~~Fewest chips~~ **Not worth it** |

---

## Verdict:

**RV8-S saves only 1 chip vs RV8 (26 vs 27) but is 2.5× slower and much harder to wire (serial chain timing is tricky).** The "fewest chips" advantage is gone after honest verification.

**RV8-S is not recommended for building.** The serial approach doesn't save enough chips to justify the speed loss and wiring complexity.

---

# ภาษาไทย — RV8-S สรุป

## แนวคิด:
ใช้ shift register (595) แทน register ธรรมดา (574) แล้วทำ ALU แบบ 1 บิต (ประหยัดชิป ALU)

## ปัญหาที่พบ:
1. ต้องเลือกว่า register ไหน shift → ต้องมี decoder + AND gate (+3 ชิป)
2. ต้องเลือกว่า register ไหนส่งข้อมูลออก → ต้องมี decoder (+1 ชิป)
3. PC ต้องมี buffer เหมือน RV8 (+2 ชิป)
4. Flash 8 บิตไม่พอ → ต้องใช้ 2 ตัว (+1 ชิป)

## ผลลัพธ์จริง:
- ประหยัดได้แค่ 1 ชิป (26 vs 27)
- แต่ช้ากว่า 2.5 เท่า
- ต่อสายยากกว่ามาก

## สรุป: **ไม่คุ้ม** ประหยัดชิปน้อยเกินไป แลกกับความเร็วและความยากในการต่อ
