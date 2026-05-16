# RV8 Project: Minimal 8-bit RISC-V Style CPU Family

Build real computers from 74HC chips. Run BASIC. Play games.

---

## The Family (5 variants, same ISA*)

| | RV8-S | RV8-R | RV8-WR | RV8 | RV8-WF |
|--|:---:|:---:|:---:|:---:|:---:|
| **Logic chips** | **15** | **17** | 19 | 27 | 27 |
| **Total** | 18 | 20 | 21 | 29 | 29 |
| **MIPS @10MHz** | 0.3 | 1.0 | **1.7** | 1.25 | **1.7** |
| **Full ISA** | ✅ | ✅ | ❌ (20 instr) | ✅ | ✅ |
| **Microcode** | Yes | Yes | **No** | Yes | **No** |
| **AND/OR/XOR** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Games** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Best for** | Ultra-min | **Fewest+full** | Cheapest games | Proven | **No microcode** |

*RV8, RV8-R, RV8-S, RV8-WF share the same 35-instruction ISA (binary compatible).
RV8-WR has a reduced 20-instruction subset.

---

## Pro/Con Summary

| Variant | Pro | Con |
|---------|-----|-----|
| **RV8-S** | Fewest chips (15) | Too slow for games |
| **RV8-R** | Fewest chips with full ISA (17) | Needs microcode Flash |
| **RV8-WR** | Cheapest that plays games (19), no microcode | Missing AND/OR/XOR, no relative branch |
| **RV8** | Most proven, easiest to modify | Most chips (27), needs microcode |
| **RV8-WF** | Full ISA + no microcode + fastest | Same chips as RV8, complex wiring |

---

## Which to build?

| Your priority | Build | Why |
|---------------|-------|-----|
| Fewest chips, full ISA | **RV8-R** (17 chips) | Best chip/capability ratio |
| No microcode, plays games | **RV8-WR** (19 chips) | Simple, no Flash to program |
| Full ISA, no microcode | **RV8-WF** (27 chips) | Same as RV8 but no microcode hassle |
| Learn microcode design | **RV8** (27 chips) | Educational, proven, has working Verilog |
| Absolute minimum | **RV8-S** (15 chips) | Academic exercise only |

---

## Shared Across All Variants

- **RV8-Bus**: 40-pin connector (A[15:0] + D[7:0] + control)
- **Programmer board**: ESP32 + TXB0108 (flash ROM + terminal)
- **Register ABI**: r0=zero, r1=a0, r2=a1, r3=t0, r4=t1, r5=s0, r6=s1, r7=sp/ra
- **RISC-V naming**: ADD, SUB, LB, SB, BEQ, JAL, etc.

---

## Project Structure

```
RV8/
├── RV8/            ← 27 chips, hardware regs, microcode (proven, Verilog works)
├── RV8R/           ← 17 chips, RAM regs, microcode (fewest + full ISA)
├── RV8W/           ← 19-27 chips, no microcode (WF=full, WR=reduced)
├── RV8S/           ← 15 chips, serial ALU (academic)
├── Programmer/     ← ESP32 board (works with all)
├── Old_Design/     ← Archived experiments
├── Reference/      ← Gigatron, SAP-1, Nand2Tetris
└── README.md
```

---

## Status

| | RV8 | RV8-R | RV8-WF | RV8-WR | RV8-S |
|--|:---:|:---:|:---:|:---:|:---:|
| Design doc | ✅ | ✅ | ✅ | ✅ | ✅ |
| Verilog | ✅ (8/8 microcode) | ⬜ | ⬜ | ⬜ | ⬜ |
| WiringGuide | ✅ | ⬜ | ✅ | ✅ | ✅ |
| Module guide | ✅ | ⬜ | ✅ | ⬜ | ✅ |
| Assembler | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Programmer board | ✅ | ✅ | ✅ | ✅ | ✅ |
