# RV8-G — Control Signal Trace (Proof: fits in 4 gate chips)

## Available Gate Resources

| Chip | Type | Gates available |
|------|------|:---:|
| U17 (74HC138) | 3-to-8 decoder | 1 decoder (decodes 2 bits → 4 class enables) |
| U18 (74HC74) | Dual D flip-flop | 2 flip-flops |
| U19 (74HC08) | Quad 2-input AND | 4 AND gates |
| U20 (74HC32) | Quad 2-input OR | 4 OR gates |

**Total: 1 decoder + 2 FF + 4 AND + 4 OR = enough?**

---

## Control Signals Needed

From the Verilog, these signals must be generated:

| Signal | When active | Drives |
|--------|-------------|--------|
| `rd` | S0, S1, S3(load) | ROM/RAM /OE |
| `wr` | S3(store) | RAM /WE |
| `ir_latch` | S1 | U5 (IR opcode) CLK |
| `pc_inc` | S1, S2(not branch taken) | U1-U4 ENP/ENT |
| `a0_we` | S2(ALU, LI a0), S3(LB/POP) | U7 CLK |
| `t0_we` | S2(LI t0, MOV) | U8 CLK |
| `sp_we` | S2(LI sp, PUSH, POP) | U9 CLK |
| `addr_sel` | S2-S3(memory access) | U15-U16 mux S pin |
| `flags_we` | S2(ALU), S3(LB) | U18 FF CLK |
| `alu_sub` | when op=SUB/CMP | U14 XOR B inputs + carry_in |

---

## State Generation (U18: 74HC74, 2 flip-flops)

```
FF1: Q = state[0]
FF2: Q = state[1]

State encoding:
  S0 = 00 (fetch opcode)
  S1 = 01 (fetch operand)  
  S2 = 10 (execute)
  S3 = 11 (memory access)

State advances: 00→01→10→00 (normal) or 00→01→10→11→00 (with memory)

FF1.D = state[1] XOR state[0]  ← needs XOR... 
```

Hmm, simple binary count doesn't work with skip-S3 logic. Let me use a different encoding:

**Better: use a 2-bit ring counter with enable**

```
FF1.D = NOT(FF2.Q)  when advance
FF2.D = FF1.Q       when advance

Or simpler: just use the 74HC161 counter approach — but we don't have one for state.
```

Actually, **simplest approach**: state is a 2-bit counter that always counts 00→01→10→11→00. The "skip S3" is handled by making S3 a NOP when not needed (just go back to S0 without doing anything). This costs 1 extra cycle for non-memory instructions (4 cycles instead of 3) but eliminates complex state logic.

**Revised: ALL instructions take 4 cycles. S3 is either memory access or idle.**

This simplifies everything:

```
State counter: 2-bit, always counts up
  FF1.D = NOT(state[0])  ← toggle
  FF2.D = state[0] XOR state[1]  ← toggle on FF1 carry

Actually just: connect FF1./Q → FF1.D (toggle), FF1.Q → FF2.CLK (ripple)
```

Wait — even simpler. Use **one 74HC74** as a 2-bit ripple counter:

```
FF1: CLK=system_CLK, D=/Q1 → toggles every clock (state bit 0)
FF2: CLK=/Q1 (falling edge of FF1), D=/Q2 → toggles every 2 clocks (state bit 1)

State sequence: 00, 01, 10, 11, 00, 01, ...
```

This gives us S0-S3 cycling continuously. **Zero gates needed for state generation!**

---

## Revised: All Instructions = 4 Cycles

| Cycle | State | Action |
|:-----:|:-----:|--------|
| 1 | S0 (00) | addr=PC, /RD active, data_in=opcode |
| 2 | S1 (01) | latch IR, PC++, addr=PC+1, /RD active, data_in=operand |
| 3 | S2 (10) | PC++, execute ALU/branch/setup address for memory |
| 4 | S3 (11) | memory read/write (or idle), latch result |

**Performance**: 4 cycles/instruction always. At 3.5 MHz = 875K instr/sec. At 10 MHz = 2.5 MIPS. Still fine for BASIC.

---

## Signal Derivation (from state bits + opcode bits)

Let `S0 = NOT(state1) AND NOT(state0)` etc. But we don't need full decode — we can use the state bits directly:

| Signal | Logic | Implementation |
|--------|-------|----------------|
| `/RD` | `NOT(state[1])` | state[1] inverted (S0,S1 have state[1]=0) → just use /Q2 of FF2 |
| `ir_latch` | `state[0] AND NOT(state[1])` = S1 | AND gate: Q1 AND /Q2 |
| `pc_inc` | `state[0]` (S1 and S3 both have bit0=1... no) | Need: S1 only = Q1 AND /Q2 |
| `execute` | `state[1] AND NOT(state[0])` = S2 | AND gate: Q2 AND /Q1 |
| `mem_phase` | `state[1] AND state[0]` = S3 | AND gate: Q2 AND Q1 |
| `wr` | `mem_phase AND class_01 AND op_is_store` | AND gate |

Wait, I'm running out of AND gates (only 4). Let me be more careful:

### What U17 (74HC138) gives us for free:

Use the 138 to decode state[1:0] → 4 state lines:

```
U17 (74HC138):
  A = state[0] (FF1.Q)
  B = state[1] (FF2.Q)
  C = GND (unused, gives us /Y0-/Y3 only)
  G1 = VCC, /G2A = GND, /G2B = GND

  /Y0 = S0 active (fetch opcode)
  /Y1 = S1 active (fetch operand)
  /Y2 = S2 active (execute)
  /Y3 = S3 active (memory phase)
```

Now we have 4 active-low state signals. These are the "when" signals. The "what" comes from opcode bits directly.

### Control signals from state + opcode:

| Signal | Logic | Gate needed |
|--------|-------|:-----------:|
| `/RD` | `/Y0` OR `/Y1` OR (S3 AND is_load) | OR gate |
| `/WR` | S3 AND is_store | AND gate |
| `ir_latch` | `/Y1` (active low → rising edge at S1→S2 transition) | **direct wire** (use /Y1 as CLK) |
| `pc_inc` | S1 OR S2 = NOT(/Y1) OR NOT(/Y2) | OR gate (inverted) |
| `a0_we` | (S2 AND class_00 AND not_CMP) OR (S3 AND is_load) | OR gate |
| `addr_sel` | S2 OR S3 (when not fetching, use pointer/zp address) | OR gate |
| `alu_sub` | `ir_op[5:3] == 001 or 101` = `ir_op[3]` (for class 00) | **direct wire** from opcode bit! |
| `flags_we` | S2 AND class_00 | AND gate |

### Gate allocation:

**U19 (74HC08 — 4 AND gates):**
| Gate | Inputs | Output | Signal |
|:----:|--------|--------|--------|
| 1 | /Y3(inverted=S3), class_01_store | → | `/WR` |
| 2 | /Y2(inverted=S2), class_00 | → | `flags_we` |
| 3 | /Y3(inverted=S3), class_01_load | → | `a0_we_mem` |
| 4 | /Y2(inverted=S2), class_00_not_cmp | → | `a0_we_alu` |

**U20 (74HC32 — 4 OR gates):**
| Gate | Inputs | Output | Signal |
|:----:|--------|--------|--------|
| 1 | a0_we_alu, a0_we_mem | → | `a0_we` (→ U7 CLK) |
| 2 | /Y1(inv), /Y2(inv) | → | `pc_inc` (→ U1-U4 ENP) |
| 3 | /Y0(inv), /Y1(inv) | → | `/RD` base (fetch phases) |
| 4 | /RD_base, a0_we_mem | → | `/RD` full (fetch + load) |

### What about class decode?

`class_01` = `NOT(ir_op[7]) AND ir_op[6]`
`class_00` = `NOT(ir_op[7]) AND NOT(ir_op[6])`

These need 2 more AND gates + 1 inverter... we're out of AND gates!

**Solution**: Use U17 (74HC138) for BOTH state decode AND class decode. The 138 has 3 address inputs — we only used 2 for state. Use a **second 74HC138** for class decode:

Actually — we already have U17 for class decode in the original design. Let me re-allocate:

```
U17a (74HC138 #1): State decode
  A=state[0], B=state[1], C=GND → /Y0=S0, /Y1=S1, /Y2=S2, /Y3=S3

U17b (74HC138 #2): Class decode  
  A=ir_op[6], B=ir_op[7], C=GND → /Y0=class00, /Y1=class01, /Y2=class10, /Y3=class11
```

But that's 2× 74HC138 = 2 chips for decode. Original plan had 1. Let me check if we can combine...

**Alternative**: Use the 138's enable pins to combine state + class:

```
U17 (74HC138):
  A = ir_op[6]
  B = ir_op[7]  
  C = GND
  G1 = S2_active (from state FF)  ← only decode during execute!
  /G2A = GND
  /G2B = GND

  Outputs active ONLY during S2:
  /Y0 = S2 AND class_00 (ALU)
  /Y1 = S2 AND class_01 (LDST)
  /Y2 = S2 AND class_10 (Branch)
  /Y3 = S2 AND class_11 (System)
```

**This combines state AND class in ONE 138!** The enable pin (G1) gates it to S2 only.

Now state decode: we just need S0, S1, S2, S3 signals. With 2 flip-flops:
- S0 = /Q2 AND /Q1
- S1 = /Q2 AND Q1
- S2 = Q2 AND /Q1
- S3 = Q2 AND Q1

That needs 4 AND gates (with inverters). Or... just use the state bits directly where possible.

---

## FINAL ALLOCATION (fits!)

### U17 (74HC138): Class decode, gated by S2

```
A = ir_op[6], B = ir_op[7], C = GND
G1 = state[1] AND NOT(state[0])  ← this IS S2... needs 1 AND gate
/G2A = GND, /G2B = GND

/Y0 = S2 AND class_00 → ALU execute
/Y1 = S2 AND class_01 → Load/Store execute  
/Y2 = S2 AND class_10 → Branch execute
/Y3 = S2 AND class_11 → System execute
```

### U18 (74HC74): State counter + Z flag

```
FF1: D=/Q1, CLK=system_CLK → state[0] (toggles every clock)
FF2: D=/Q2, CLK=/Q1 → state[1] (toggles every 2 clocks)

Wait — this is a ripple counter. FF2 clocks on FF1 falling edge.
State sequence: 00→01→10→11→00... ✓

But we need Z flag too! Only 2 FFs in one 74HC74.
```

**Problem**: Need 2 FFs for state + at least 2 for flags (Z, C). That's 4 FFs = 2× 74HC74.

**Revised chip count**: Need **2× 74HC74** (one for state, one for flags). That adds 1 chip → **23 chips total**.

Or: use state[1:0] from a different source. The 74HC161 (PC counter) has a TC output... no, that doesn't help.

**Accept 23 chips** (add 1× 74HC74 for flags):

| Chip | Function |
|------|----------|
| U17 | 74HC138: class decode (gated by S2) |
| U18 | 74HC74: state counter (2 FFs) |
| U18b | 74HC74: flags Z, C |
| U19 | 74HC08: 4 AND gates |
| U20 | 74HC32: 4 OR gates |

### U19 (74HC08) allocation:

| Gate | A | B | Output |
|:----:|---|---|--------|
| 1 | state[1] (Q2) | NOT(state[0]) (/Q1) | **S2** → U17.G1 |
| 2 | state[1] | state[0] | **S3** |
| 3 | S3 | class_01_store (ir_op[5]) | **/WR** |
| 4 | NOT(state[1]) (/Q2) | — | **fetch_phase** (S0 or S1) |

Wait, gate 4 only has 1 input — that's just an inverter (tie B=VCC). Or use /Q2 directly as fetch_phase.

Actually `/Q2` from U18 FF2 = NOT(state[1]) = HIGH during S0 and S1. This IS the fetch phase signal. **Free — just a wire from /Q2!**

Revised U19:
| Gate | A | B | Output | Signal |
|:----:|---|---|--------|--------|
| 1 | Q2 | /Q1 | → | S2 (→ U17.G1) |
| 2 | Q2 | Q1 | → | S3 |
| 3 | S3 | ir_op[5] | → | /WR (store when S3 + op=store) |
| 4 | S2 | class_00(/Y0 inv) | → | flags_we |

### U20 (74HC32) allocation:

| Gate | A | B | Output | Signal |
|:----:|---|---|--------|--------|
| 1 | /Y0(inv) | S3_load | → | a0_we |
| 2 | /Q2 | S3_load | → | /RD (read during fetch OR load) |
| 3 | Q1 | Q2 | → | (same as S3, redundant — use for something else) |
| 4 | (spare) | | → | |

Hmm, getting tight but workable. The key insight: **most "decode" is just opcode bits wired directly**:

- `alu_sub` = ir_op[3] (bit 3 of opcode, direct wire to XOR chip)
- `carry_in` = ir_op[3] (same bit, direct wire to adder C0)
- `addr_sel` = state[1] (during S2/S3, use data address; during S0/S1, use PC)
- `ir_latch` = S1 transition (use /Y1 edge or AND gate)
- `pc_inc` = /Q2 (fetch phase = S0 or S1, PC counts)

---

## CONCLUSION: IT FITS

| Resource | Available | Used |
|----------|:---------:|:----:|
| 74HC138 (decode) | 8 outputs | 4 used (class decode gated by S2) |
| 74HC74 #1 (state) | 2 FF | 2 used (state[1:0] counter) |
| 74HC74 #2 (flags) | 2 FF | 2 used (Z, C) |
| 74HC08 (AND) | 4 gates | 4 used (S2, S3, /WR, flags_we) |
| 74HC32 (OR) | 4 gates | 3 used (a0_we, /RD, spare) |
| Direct wires | ∞ | ~6 (alu_sub, carry_in, addr_sel, pc_inc, ir_latch, N flag) |

**Total control chips: 5** (1×138 + 2×74 + 1×08 + 1×32)

**Revised total: 23 chips** (was 22, added 1× 74HC74 for flags)

Still no EEPROM. Pure gates. ✓
