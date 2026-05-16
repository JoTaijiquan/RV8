# RV8 Project: Minimal 8-bit RISC-V Style CPU Family

Build real computers from 74HC chips. Run BASIC. Play games.

---

## The Family (4 variants)

| | **RV8-R** | **RV8-WR** | **RV8** | **RV8-WF** |
|--|:---:|:---:|:---:|:---:|
| **Logic chips** | **17** | **19** | 27 | 27 |
| **Total packages** | 20 | 21 | 29 | 29 |
| **MIPS @10MHz** | 1.0 | **1.7** | 1.25 | **1.7** |
| **ISA** | Full (35) | Reduced (20) | Full (35) | Full (35) |
| **Microcode** | Yes | **No** | Yes | **No** |
| **AND/OR/XOR** | ✅ | ❌ | ✅ | ✅ |
| **Relative branch** | ✅ | ❌ | ✅ | ✅ |
| **Binary compatible** | ✅=RV8 | ❌ own ISA | — | ✅=RV8 |
| **Games** | ✅ | ✅ | ✅ | ✅ |
| **Registers** | RAM | RAM | Hardware | RAM |

---

## Which to build?

| Priority | Build | Why |
|----------|-------|-----|
| **Fewest chips + full ISA** | **RV8-R** (17) | Best chip/capability ratio |
| **No microcode + plays games** | **RV8-WR** (19) | No Flash to program, simple |
| **Full ISA + no microcode** | **RV8-WF** (27) | No microcode hassle, fastest |
| **Learn microcode + proven** | **RV8** (27) | Has working Verilog + tests |

---

## Pro/Con

| Variant | Pro | Con |
|---------|-----|-----|
| **RV8-R** | Fewest chips (17), full ISA, binary compatible | Needs 2× Flash programmer |
| **RV8-WR** | No microcode, cheap (19 chips), plays games | Missing AND/OR/XOR, no relative branch, own ISA |
| **RV8** | Most proven, working Verilog (8/8), educational | Most chips (27), needs microcode |
| **RV8-WF** | Full ISA + no microcode + fastest (1.7 MIPS) | Same chips as RV8, complex wiring |

---

## Shared

- **RV8-Bus**: 40-pin (A[15:0] + D[7:0] + control) — same for all
- **Programmer board**: ESP32 + TXB0108 — works with all
- **Register ABI**: r0=zero, r1=a0, r2=a1, r3=t0, r4=t1, r5=s0, r6=s1, r7=sp
- **RISC-V naming**: ADD, SUB, LB, SB, BEQ, JAL, etc.

---

## Project Structure

```
RV8/
├── RV8/            ← 27 chips, hardware regs, microcode (proven)
├── RV8R/           ← 17 chips, RAM regs, microcode (fewest + full ISA)
├── RV8WF/          ← 27 chips, full ISA, no microcode, fastest
├── RV8WR/          ← 19 chips, reduced ISA, no microcode, cheapest games
├── Programmer/     ← ESP32 board (works with all)
├── Old_Design/     ← Archived (RV8-G, RV8-S, RV808, RV801, original)
├── Reference/      ← Gigatron, SAP-1, Nand2Tetris
└── README.md
```

---

## Status

| | RV8 | RV8-R | RV8-WF | RV8-WR |
|--|:---:|:---:|:---:|:---:|
| Design doc | ✅ | ✅ | ✅ | ✅ |
| Verilog (microcode-driven) | ✅ 8/8 | ⬜ | ⬜ | ⬜ |
| WiringGuide | ✅ | ⬜ | ✅ | ✅ |
| Understand by Module | ✅ | ⬜ | ✅ | ✅ |
| Assembler | ⬜ | ⬜ | ⬜ | ⬜ |
| Programmer board | ✅ | ✅ | ✅ | ✅ |
