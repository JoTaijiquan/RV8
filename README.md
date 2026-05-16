# RV8 Project: Minimal 8-bit RISC-V Style CPU Family

Build real computers from 74HC chips. Run BASIC. Play games.

---

## The Family

| | **RV8** | **RV8-R** | **RV8-W** | **RV8-WR** |
|--|:---:|:---:|:---:|:---:|
| **Logic chips** | 27 | **17** | 27 | **19** |
| **Total** | 29 | 20 | 29 | 21 |
| **MIPS @10MHz** | 1.25 | 1.0 | **1.7** | **1.7** |
| **ISA** | Full (35) | Full (35) | Full (35) | Reduced (21) |
| **Microcode** | Yes | Yes | **No** | **No** |
| **AND/OR/XOR** | ✅ | ✅ | ✅ | ❌ |
| **Binary compatible** | — | ✅=RV8 | ✅=RV8 | ❌ |
| **Games** | ✅ | ✅ | ✅ | ✅ |

---

## Which to build?

| Priority | Build |
|----------|-------|
| **Learn microcode + proven** | **RV8** (27 chips) |
| **Fewest chips + full ISA** | **RV8-R** (17 chips) |
| **Full ISA + no microcode** | **RV8-W** (27 chips) |
| **No microcode + cheapest games** | **RV8-WR** (19 chips) |

---

## Pro/Con

| Variant | Pro | Con |
|---------|-----|-----|
| **RV8** | Proven, working Verilog (8/8) | Most chips (27), needs microcode |
| **RV8-R** | Fewest chips (17), full ISA | Needs 2× Flash programmer |
| **RV8-W** | Full ISA, no microcode, fastest | Same chips as RV8, complex wiring |
| **RV8-WR** | No microcode, cheap (19), games | Own ISA, no logic ops |

---

## Project Structure

```
RV8/
├── RV8/            ← 27 chips, hardware regs, microcode (proven)
├── RV8R/           ← 17 chips, RAM regs, microcode (fewest + full ISA)
├── RV8W/           ← 27 chips, full ISA, no microcode, fastest
├── RV8WR/          ← 19 chips, reduced ISA, no microcode, cheapest
├── Programmer/     ← ESP32 board (works with all)
├── Old_Design/     ← Archived
├── Reference/      ← Gigatron, SAP-1, Nand2Tetris
└── README.md
```

---

## Shared Across All

- **RV8-Bus**: 40-pin (A[15:0] + D[7:0] + control)
- **Programmer**: ESP32 + TXB0108 (flash + terminal)
- **Registers**: r0=zero, r1=a0, r2=a1, r3=t0, r4=t1, r5=s0, r6=s1, r7=sp
- **RISC-V naming**: ADD, SUB, LB, SB, BEQ, JAL

---

## Status

| | RV8 | RV8-R | RV8-W | RV8-WR |
|--|:---:|:---:|:---:|:---:|
| Design doc | ✅ | ✅ | ✅ | ✅ |
| Verilog | ✅ 8/8 | ⬜ | ⬜ | ⬜ |
| WiringGuide | ✅ | ⬜ | ⬜ | ✅ |
| Module guide | ✅ (Thai+EN) | ⬜ | ✅ | ✅ |
| Assembler | ⬜ | ⬜ | ⬜ | ⬜ |
| Programmer | ✅ | ✅ | ✅ | ✅ |
