# RV802-W — Wide Instruction, No Microcode

**24 logic chips. 2-cycle instructions. 5 MIPS @ 10 MHz. No microcode ROM.**

---

## Architecture

```
Program ROM (8-bit, SST39SF010A):
  Byte 0: CONTROL byte (IR_HIGH) — bits directly drive hardware
  Byte 1: OPERAND byte (IR_LOW) — immediate value / register select

Cycle 1: fetch CONTROL → IR_HIGH latches → PC++
Cycle 2: fetch OPERAND → IR_LOW latches → EXECUTE (IR_HIGH drives hardware) → PC++

No microcode. No step counter. Control byte IS the control signals.
```

---

## Instruction Encoding (16-bit = 2 bytes)

### Byte 0 (CONTROL — directly drives hardware):

```
Bit 7:    ALU_SUB (0=ADD, 1=SUB — to XOR chips)
Bit 6-4:  ALU_OP[2:0] (000=ADD, 001=SUB, 010=AND, 011=OR, 100=XOR, 101=PASS, 110=SHL, 111=SHR)
Bit 3:    MEM_ACCESS (1=this instruction accesses memory)
Bit 2:    MEM_WRITE (1=store, 0=load)
Bit 1:    REG_WRITE (1=write result to destination register)
Bit 0:    BRANCH (1=this is a branch/jump instruction)
```

### Byte 1 (OPERAND):

```
For ALU reg-reg:  [rd(3)][rs(3)][00]
For ALU imm:      [rd(3)][imm5(5)]  — or full 8-bit imm with rd from control
For Load/Store:   [rd(3)][rs(3)][off2] — or [rd(3)][imm5]
For Branch:       [cond(3)][offset5]  — or [rs1(3)][rs2(2)][off3]
```

Actually — let me simplify. Since control byte has 8 bits and operand has 8 bits:

### Revised encoding:

```
CONTROL byte (drives hardware directly):
  Bit 7:   PHASE (0=fetch/execute, 1=memory access cycle)
  Bit 6-4: DEST[2:0] — destination register (write select → 138 decoder)
  Bit 3-1: SRC[2:0] — source register (read select → 138 decoder)  
  Bit 0:   ALU_MODE (0=ADD, 1=SUB/compare)

OPERAND byte:
  For immediate ops: imm8 (full 8-bit immediate)
  For register ops:  [rs2(3)][00000] (source 2 for ALU B)
  For branches:      [cond(3)][offset5]
```

Hmm — 8 control bits isn't enough to encode ALU op + dest + source + memory + branch all at once.

---

## The real problem: 8 control bits is tight

Need to encode per instruction:
- What operation (ADD/SUB/AND/OR/XOR/SHL/SHR/PASS) = 3 bits
- Destination register = 3 bits
- Source register = 3 bits
- Memory access? = 1 bit
- Branch? = 1 bit
- Total = 11 bits minimum

Only have 8 bits in control byte. **3 bits short.**

### Solution: Use BOTH bytes for encoding (not pure "control + operand" split)

```
Byte 0: [class(2)][op(3)][rd(3)]        — same as RV802!
Byte 1: [rs(3)][imm5(5)] or [imm8]      — same as RV802!
```

This is... exactly the current RV802 encoding. The difference is HOW we use it:

**Instead of microcode translating opcode → control signals, we use a SMALL FIXED DECODER (74HC138 + gates) that directly maps opcode bits to control wires.**

The control byte bits map to hardware:
- `class[1:0]` (byte0[7:6]) → 74HC139 decoder → 4 class enables
- `op[2:0]` (byte0[5:3]) → ALU op select (direct wire to ALU control)
- `rd[2:0]` (byte0[2:0]) → 74HC138 → register write select

The operand byte:
- `rs[2:0]` (byte1[7:5]) → 74HC138 → register read select
- `imm[4:0]` or `imm[7:0]` → ALU B input / address offset

**This is the RV8-G approach but with the 2-cycle fetch!**

---

## Wait — this brings back the decode problem

If we use opcode bits directly as control, we're back to RV8-G's issues:
- Need gates to generate all control signals from opcode bits
- AND/OR/XOR need ALU mode selection beyond just SUB bit
- Memory access needs address routing

**The 2-cycle fetch doesn't help with decode complexity — it only helps with fetch speed.**

---

## Honest assessment:

| Approach | Decode method | Chips for decode | Total |
|----------|:---:|:---:|:---:|
| RV802 (microcode) | Flash lookup | 2 (Flash) + 1 (step counter) | 29 |
| RV802-W (2-cycle, gates decode) | Direct gates | ~5-6 (138+139+08+32+...) | 28-30 |
| RV802-W (2-cycle, small EEPROM) | 1× AT28C64 (8KB) | 1 chip | **26** |

**The 2-cycle fetch with a SMALL EEPROM (AT28C64, 8KB) for decode is the sweet spot:**

```
Cycle 1: ROM → IR_HIGH (opcode) → AT28C64 address → control signals appear
Cycle 2: ROM → IR_LOW (operand) → EXECUTE (control already active from cycle 1)
```

The AT28C64 is tiny (8KB, DIP-28, $2) and acts as a **combinational decoder** — opcode in, control signals out. Not microcode (no step sequencing), just a lookup table replacing gates.

---

## RV802-W Final Design:

```
Program ROM: SST39SF010A (128KB, 8-bit, holds program)
Decode ROM:  AT28C64 (8KB, 8-bit, holds opcode→control mapping)
             Address: opcode[7:0] + flags[1:0] + IRQ = 11 bits (2KB used)
             Data: 8 control signals

Or: skip decode ROM, use 16-bit program ROM (27C1024) — control bits IN the instruction.
```

---

## Simplest RV802-W (with 27C1024):

Back to the original idea: **one 16-bit ROM, instruction IS control.**

| Chip | Count | Function |
|------|:-----:|----------|
| 74HC574 ×8 | 8 | Registers r0-r7 |
| 74HC574 ×1 | 1 | IR_HIGH (control byte, drives hardware) |
| 74HC574 ×1 | 1 | IR_LOW (operand, feeds ALU B + address) |
| 74HC283 ×2 | 2 | ALU adder |
| 74HC86 ×1 | 1 | XOR (SUB) — only need 1 if control byte has full ALU select |
| 74HC161 ×4 | 4 | PC (16-bit, auto-increment) |
| 74HC541 ×1 | 1 | PC high buffer (tri-state) |
| 74HC157 ×1 | 1 | Address mux low (PC vs pointer) |
| 74HC138 ×1 | 1 | Register read select (from operand rs field) |
| 74HC138 ×1 | 1 | Register write select (from control rd field) |
| 74HC245 ×1 | 1 | Bus buffer |
| 74HC74 ×1 | 1 | Flags + fetch/execute toggle |
| 27C1024 ×1 | 1 | Program ROM (16-bit wide) |
| 62256 ×1 | 1 | RAM |
| **Total** | **24 logic + ROM + RAM = 26** | |

---

## VERIFICATION — trace ADD r1, r1, r2:

### Cycle 1 (fetch, state=0):

```
State FF = 0 (fetch mode)
PC → address bus → 27C1024 address pins
27C1024 outputs 16 bits:
  D[15:8] → IR_HIGH (574) latches on CLK rising edge
  D[7:0]  → IR_LOW (574) latches on CLK rising edge
PC increments (PC += 2, since 16-bit word = 2 addresses... 

WAIT — 27C1024 is word-addressed (A0-A15 = 64K words).
PC counts WORDS not bytes. PC++ = next instruction. ✅
```

Actually: 27C1024 has 16 address pins, outputs 16 data pins simultaneously. PC drives address, both bytes come out at once. **ONE cycle fetch!**

### Revised: 1 cycle per instruction!

```
Cycle 1: PC → 27C1024 → D[15:8]=control, D[7:0]=operand → BOTH latch → EXECUTE
          IR_HIGH drives hardware (ALU op, dest, source select)
          IR_LOW provides operand (immediate or rs field)
          ALU computes combinationally
          Result latches into destination register at end of cycle
          PC increments
```

**ONE CYCLE PER INSTRUCTION = 10 MIPS @ 10 MHz!**

But wait — for memory access (LB/SB), we need a second cycle:
```
Cycle 1: fetch + compute address
Cycle 2: memory read/write
```

So: ALU/branch = 1 cycle, memory = 2 cycles. Average ~1.3 cycles = **7.7 MIPS!**

---

## VERIFICATION — does the wiring work?

### Address bus during fetch:
- PC (U13-U16, 74HC161) drives address → 27C1024 address pins ✅
- 27C1024 D[15:8] → IR_HIGH (U9) D inputs ✅
- 27C1024 D[7:0] → IR_LOW (U10) D inputs ✅
- Both latch on CLK ✅

### Register read (source):
- IR_LOW[7:5] = rs field → U11 (74HC138) A,B,C → selects register /OE ✅
- Selected register Q outputs → IBUS → ALU B input (via XOR) ✅

### Register write (destination):
- IR_HIGH[2:0] = rd field → U12 (74HC138) A,B,C → selects register CLK ✅
- ALU result → destination register D inputs ✅

### ALU operation:
- IR_HIGH[6:4] = ALU op → directly to ALU control (XOR enable, etc.) ✅
- ALU A = destination register output (hardwired? or from IBUS?)

### 🚨 PROBLEM: ALU A input

ALU A needs the DESTINATION register value. But the destination register's /OE is not enabled (only source register drives IBUS).

**Fix options:**
A. Hardwire one register (a0) as ALU A always → back to accumulator ❌
B. ALU A comes from IBUS too → need to read rd FIRST, then rs → needs 2 cycles ❌
C. Registers have TWO output ports → need 2× 138 decoders + separate bus for ALU A

**Option C**: Add a second read bus (ALU_A bus):
- 138 #1 selects rs → drives IBUS → ALU B
- 138 #2 selects rd → drives ALU_A bus → ALU A input
- Both happen simultaneously (different buses, no conflict)

But: 74HC574 has only ONE set of Q outputs and ONE /OE. Can't drive two buses.

**Real fix**: Use the **destination register Q outputs hardwired to ALU A** (always connected, no /OE needed). The register outputs go to BOTH:
1. ALU A input (direct wire, always)
2. IBUS (via /OE, only when selected as source)

Wait — if ALL 8 registers are hardwired to ALU A, they'd all drive it simultaneously. Need a mux.

**Simplest**: Accept accumulator style. r1 (a0) is always ALU A. Other registers feed ALU B via IBUS.

This means: `ADD r1, r1, r2` works (r1=A, r2=B→IBUS). But `ADD r3, r3, r4` doesn't (r3 can't be ALU A).

**Or**: Use 74HC157 mux (2 chips for 8-bit) to select which register feeds ALU A. Controlled by rd field.

+2 chips → 26 logic. Still good.

---

## FINAL HONEST CHIP LIST:

| U# | Chip | Function |
|:--:|------|----------|
| U1-U8 | 74HC574 ×8 | Registers r0-r7 |
| U9 | 74HC574 | IR_HIGH (control byte) |
| U10 | 74HC574 | IR_LOW (operand byte) |
| U11 | 74HC138 | Register read select (rs → /OE → IBUS) |
| U12 | 74HC138 | Register write select (rd → CLK) |
| U13-U14 | 74HC157 ×2 | ALU A mux (select rd output → ALU A input) |
| U15-U16 | 74HC283 ×2 | ALU adder (8-bit) |
| U17 | 74HC86 | XOR (SUB invert) |
| U18-U21 | 74HC161 ×4 | PC (16-bit, auto-increment) |
| U22 | 74HC541 | PC high buffer (tri-state for data access) |
| U23 | 74HC157 | Address mux low (PC vs register for data access) |
| U24 | 74HC245 | External bus buffer |
| U25 | 74HC74 | Flags (Z,C) + state (fetch/execute) |
| — | 27C1024 | Program ROM (16-bit wide, DIP-40) |
| — | 62256 | RAM |
| **Total** | **25 logic + ROM + RAM = 27** | |

### Or with 8-bit ROM (2-cycle fetch):
Replace 27C1024 with SST39SF010A. Add 1 state FF for fetch/execute toggle.
Same 25 logic chips. 2 cycles/instruction = 5 MIPS.

---

## VERIFICATION SUMMARY:

| Signal path | Works? | Notes |
|-------------|:------:|-------|
| PC → ROM → IR latch | ✅ | 16-bit ROM or 2-cycle 8-bit |
| rs field → 138 → register /OE → IBUS → ALU B | ✅ | Via XOR for SUB |
| rd field → 157 mux → ALU A | ✅ | 2× 157 selects which register feeds A |
| ALU result → register D input | ⚠️ | Need path: ALU output → selected register D |
| rd field → 138 → register CLK | ✅ | Write select |
| Memory access (address from register) | ⚠️ | Need address latch or mux |
| Branch (PC load) | ⚠️ | Need ALU result → PC load path |

### Remaining issues:
1. **ALU result → register D**: All register D inputs must connect to ALU output (parallel, always). Only the CLK'd register captures. ✅ (same as RV802)
2. **Memory address**: Need register value on address bus for LB/SB. Needs 2nd cycle + address latch (same as RV802). +1 or +2 chips for address latches.
3. **Branch PC load**: PC (74HC161) /LD pin loads from D inputs. D inputs need ALU result (PC+offset). Need path from ALU → PC D inputs.

### With address latches for memory:
+2× 74HC574 (addr latch low + high) = **27 logic + ROM + RAM = 29**

Hmm — back to 29 again for full memory access.

### Or: use accumulator + pointer (like Gigatron):
- Only r1 (accumulator) does ALU
- Memory access only via pointer register (hardwired to address bus)
- Eliminates ALU A mux and address latches
- Back to ~24 logic chips but loses RISC-V style

---

## HONEST CONCLUSION:

| Design | Logic chips | MIPS | RISC-V? | Buildable? |
|--------|:-----------:|:----:|:-------:|:----------:|
| RV802 (microcode) | 27 | 2.17 | ✅ Yes | ✅ (verified) |
| RV802-W (16-bit ROM) | 25-27 | 5-10 | ⚠️ Partial | ⚠️ (ALU A mux + addr latch issues) |
| RV802-W (accumulator) | 24 | 10 | ❌ No | ✅ (Gigatron proven) |

**The RISC-V register-to-register style always costs more chips** because it needs:
- ALU A source mux (which register feeds A?)
- ALU B source mux (which register feeds B?)
- These muxes don't exist in accumulator designs

**RV802 with microcode remains the best RISC-V style option at 27-29 chips.**
**Gigatron/accumulator style is fewer chips but loses RISC-V feel.**
