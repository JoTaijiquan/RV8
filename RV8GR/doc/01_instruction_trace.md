# RV8-GR — Instruction Trace

**Trace `ADDI a0, a0, 5` through every chip, every cycle.**

---

## Setup:
- AC = $10 (current value)
- PC = $8000 (pointing to ROM)
- ROM[$8000] = $14 (control byte: ADD, imm, AC_WR, no store)
- ROM[$8001] = $05 (operand: immediate value 5)
- Expected result: AC = $10 + $05 = $15

## Control byte $14 = `0001_0100`:
```
Bit 7: ALU_SUB=0      (ADD mode)
Bit 6: XOR_MODE=0     (not XOR)
Bit 5: MUX_SEL=0      (adder result → AC)
Bit 4: AC_WR=1        (write to AC) ✅
Bit 3: SOURCE_TYPE=0  (immediate, operand=value)
Bit 2: STORE=0        (not storing)
Bit 1: BRANCH=0       (not branch)
Bit 0: JUMP=0         (not jump)

Derived: ADDR_MODE=0 (PC drives address), BUF_OE=0 (no RAM access)
```

Wait — if BUF_OE=0, how does the immediate value get to IBUS?

**Problem found!** For immediate mode (SOURCE_TYPE=0), the operand value needs to reach IBUS (→ ALU B). But BUF_OE is derived from `SOURCE_TYPE OR STORE` = `0 OR 0` = 0. Buffer disabled!

**The immediate value comes from ROM via the bus buffer.** During execute cycle, the operand is already latched in IR_LOW (U8). But IR_LOW outputs go to address mux, not IBUS!

**Issue**: How does immediate value reach IBUS for ALU B?

---

## Options:

### A: IR_LOW drives IBUS directly (add /OE control)
IR_LOW (U8, 74HC574) has /OE pin. If /OE=LOW during immediate execute, IR_LOW Q outputs drive IBUS.

But IR_LOW Q outputs currently go to address mux (U7, U13). If they ALSO drive IBUS, that's two destinations from same pins — OK (just wire to both). But need /OE control:
- During fetch: /OE=HIGH (don't drive IBUS while fetching)
- During execute (immediate): /OE=LOW (drive IBUS with operand value)

**This works!** IR_LOW /OE = NOT(SOURCE_TYPE) AND STATE_EXECUTE. When immediate mode + execute state → operand on IBUS.

But wait — IR_LOW /OE is currently GND (always output) for address mux. If we control /OE, address mux loses its input during non-execute cycles.

**Fix**: Address mux has its own /E (enable) pin. During fetch, mux is in PC mode anyway (ADDR_MODE=0), so operand value on mux B-input doesn't matter. **No conflict!**

IR_LOW /OE = controlled:
- Fetch cycles: /OE=HIGH (outputs high-Z, doesn't matter — mux selects PC)
- Execute + immediate: /OE=LOW (drives IBUS with operand)
- Execute + register: /OE=LOW (drives address mux with register address)

Actually IR_LOW needs to drive address mux ALWAYS during execute (for both immediate and register modes). For register mode, operand = RAM address → goes to address mux. For immediate mode, operand = value → goes to IBUS.

**These are the SAME pins going to DIFFERENT places!** Can't do both from one output.

---

## Real fix: Separate the paths

IR_LOW Q outputs go to:
1. Address mux B-inputs (always connected, for register addressing)
2. IBUS (for immediate values)

Both at the same time? Yes! 574 Q outputs can drive multiple loads. The address mux B-inputs are always connected (just ignored when ADDR_MODE=0). IBUS gets the same value.

**But**: If IBUS has another driver active (like U10 bus buffer reading RAM), conflict!

During immediate mode: SOURCE_TYPE=0 → BUF_OE=0 → bus buffer disabled. So IBUS is free. IR_LOW can drive it.

**Solution**: Wire IR_LOW Q outputs to BOTH address mux AND IBUS. During immediate execute, nothing else drives IBUS (buffer disabled), so IR_LOW value appears on IBUS. ✅

**But**: IR_LOW /OE must be LOW during execute. Currently /OE=GND (always). That means IR_LOW ALWAYS drives IBUS — even during fetch when ROM data should be on IBUS via buffer!

**Conflict during fetch**: Buffer (U10) drives IBUS with ROM data AND IR_LOW drives IBUS with old operand. **BUS CONFLICT!**

---

## Real real fix: IR_LOW /OE must be controlled

```
IR_LOW /OE:
  Fetch cycles: HIGH (disconnected from IBUS, buffer drives IBUS)
  Execute cycle: LOW (drives IBUS with operand value)
```

Control signal: `/OE = NOT(STATE_EXECUTE)` = fetch state.

This uses the STATE output from U14 FF2. When STATE=0 (fetch): /OE=HIGH. When STATE=1 (execute): /OE=LOW.

**No extra chip needed** — just wire U14.STATE to U8./OE (inverted: /OE = NOT(STATE) = /Q from FF2).

Wait — we need NOT(STATE) = fetch. U14 FF2 has both Q (STATE) and /Q (/STATE). Use /Q → U8./OE.

**U8./OE = U14./Q (pin 8 of U14)** ← fetch state = HIGH = disconnected. Execute state = LOW = drives IBUS.

**Fix: change U8 pin 1 from GND to U14.pin8 (/Q).** Zero extra chips! ✅

---

## Revised trace (with fix applied):

### Cycle 1: FETCH CONTROL (STATE=0)

| Chip | What happens |
|------|-------------|
| U14 | STATE=0 (/Q=HIGH) |
| U15-U18 (PC) | PC=$8000 drives address bus A[15:0] |
| U13+U7 (addr mux) | ADDR_MODE=0 → selects PC → A[7:0]=PC[7:0] |
| ROM | /CE active (A15=1), /OE=/RD=LOW → outputs $14 on D[7:0] |
| U10 (245) | BUF_OE... wait, who enables it during fetch? |

**Another issue**: During fetch, we need ROM data on IBUS (to latch into IR). But BUF_OE = SOURCE_TYPE OR STORE = from IR_HIGH... which hasn't been latched yet (we're fetching it now)!

**The fetch cycle needs BUF_OE=1 regardless of instruction.** It's always needed during fetch.

**Fix**: BUF_OE = FETCH_STATE OR (SOURCE_TYPE OR STORE)
= NOT(STATE) OR SOURCE_TYPE OR STORE

During fetch (STATE=0): BUF_OE=1 (always read ROM)
During execute: BUF_OE = SOURCE_TYPE OR STORE (only if accessing RAM)

**Needs 1 OR gate.** Use spare from... we don't have spare OR gates in 19-chip design.

**Add 1× 74HC32 (OR gate chip)?** That's +1 chip = 20 logic chips.

**Or**: Tie BUF_OE to a simpler signal. Actually: during fetch, /RD is active (reading ROM). The buffer should be enabled whenever /RD is active.

**Simplest**: BUF_OE = /RD (active low). Buffer enabled whenever memory is being read. /RD = NOT(STATE) OR (STATE AND SOURCE_TYPE).

This is getting complex. Let me just accept: **+1× 74HC32 for control logic = 20 chips.**

---

## HONEST REVISED COUNT: 20 logic chips

The 19-chip design was missing the fetch-enable logic for the bus buffer. Need 1 OR gate chip.

| Added | Why |
|-------|-----|
| U_extra: 74HC32 | OR gates for: BUF_OE during fetch, /RD generation, derived signals |

This 74HC32 also provides the derived signals (ADDR_MODE = SOURCE_TYPE OR STORE) that we said needed "~3 gates." Now they have a home.

**Final: 20 logic chips + ROM + RAM = 22 packages.**

---

## Trace continues (with 20 chips, all signals correct):

### Cycle 1: FETCH CONTROL (STATE=0)

| Signal | Value | Source |
|--------|-------|--------|
| STATE | 0 | U14./Q = HIGH |
| ADDR_MODE | 0 | (from previous IR_HIGH, doesn't matter — mux selects PC) |
| A[15:0] | $8000 | PC (U15-U18) via mux (ADDR_MODE=0) |
| BUF_OE | 1 | OR gate: NOT(STATE)=1 → buffer enabled |
| BUF_DIR | 0 | Read (ROM → IBUS) |
| D[7:0] | $14 | ROM output |
| IBUS | $14 | Via U10 (245) buffer |
| IR_CLK | ↑ | Pulse at end of cycle → U2 latches $14 |
| U8./OE | HIGH | /STATE=1 → IR_LOW disconnected from IBUS |
| PC_INC | 1 | NOT(STATE)=1 → PC increments to $8001 |

**Result**: IR_HIGH (U2) = $14. PC = $8001. ✅

### Cycle 2: FETCH OPERAND (STATE=1... wait)

Hmm — STATE toggles every clock. After cycle 1, STATE=1. But we need TWO fetch cycles (control + operand) before execute.

**Problem**: 1 flip-flop gives 2 states (0,1). We need 3 states (fetch1, fetch2, execute).

**Need 2-bit state counter** (3 states: 00=fetch1, 01=fetch2, 10=execute).

U14 has 2 FFs. FF1=flags(Z). FF2=state. Only 1 bit for state = 2 states only.

**For 3 states**: need 2 state bits. Use both FFs for state? Then no flags!

**Or**: Accept 2-cycle design (fetch both bytes in 1 cycle using 16-bit ROM). But we chose 8-bit ROM + 3 cycles.

**Fix**: Replace U14 (74HC74, 2 FF) with 74HC161 (4-bit counter) for state. Use separate FF for flags.

**+1 chip (74HC74 for flags) + change U14 to 74HC161 (state counter).**

Net: same chip count (swap 74HC74 for 74HC161, add 74HC74 for flags) = **+1 chip = 21 logic chips.**

---

## FINAL HONEST: 21 logic chips + ROM + RAM = 23 packages

| Issue found | Fix | Chips |
|-------------|-----|:-----:|
| Bus buffer enable during fetch | +1× 74HC32 (OR gates) | +1 |
| 3-state counter (fetch1/fetch2/execute) | Change to 74HC161 + add 74HC74 for flags | +1 |
| **Total** | | **21 logic** |

---

## This is why we trace before building!

The "19 chips" claim was missing:
1. Fetch-enable logic for bus buffer
2. 3-state sequencing (can't do 3 cycles with 1 flip-flop)

**Every time we trace honestly, we find 1-2 more chips.** The design converges to ~21 chips for RV8-GR.
