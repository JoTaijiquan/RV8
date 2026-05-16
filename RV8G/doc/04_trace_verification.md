# RV8-G — Instruction Trace Verification

## RV8-G = RV8-GR (21 chips, verified) + extra chips for full ISA

### Extra chips needed:
- +2× 74HC08 (AND operation, 8-bit)
- +2× 74HC32 (OR operation, 8-bit) — BUT 1 shared with RV8-GR's derived signal gates
- +2× 74HC157 (ALU A mux: AC vs PC for relative branch)
- +2× 74HC157 (Result mux: select adder/AND/OR/XOR → AC)

### Shared chip:
RV8-GR needs 1× 74HC32 for derived control signals (ADDR_MODE, BUF_OE).
RV8-G has 2× 74HC32 for OR instruction. These gates are time-shared:
- During OR instruction: all 8 gates compute data
- During other instructions: 2 gates compute control signals
Net: −1 chip (shared)

### Honest count:
```
RV8-GR base:           21 chips
+ AND (74HC08 ×2):     +2
+ OR (74HC32 ×2):      +2
+ ALU A mux (157 ×2):  +2
+ Result mux (157 ×2): +2
− Shared OR chip:       −1
─────────────────────────────
RV8-G total:           28 logic chips + ROM + RAM = 30 packages
```

### Bus conflict check (extra chips):
- U20-U21 (AND): read AC.Q + IBUS → output to result mux. Read-only, no bus driving. ✅
- U22-U23 (OR): same pattern. ✅
- U24-U25 (ALU A mux): between AC and adder. Replaces direct wire. No bus. ✅
- U26-U27 (Result mux): between logic outputs and AC D-mux. No bus. ✅

**No new bus conflicts.** Extra chips are all in parallel data paths, not on shared buses.

### Revised comparison:

| | Claimed | Traced honest |
|--|:---:|:---:|
| RV8-GR | 19 | **21** |
| RV8-G | 27 | **28** |
