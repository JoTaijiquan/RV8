# RV8 Project — Session Memory

**Last updated**: 2026-05-16 21:37

---

## Final Family (4 active variants)

| | RV8 | RV8-R | RV8-G | RV8-GR |
|--|:---:|:---:|:---:|:---:|
| Logic chips | 27 | **17** | 27 | **19** |
| Total | 29 | 20 | 29 | 21 |
| MIPS | 1.25 | 1.0 | **1.7** | **1.7** |
| ISA | Full (35) | Full (35) | Full (35) | Reduced (20) |
| Microcode | Yes | Yes | **No** | **No** |
| Binary compat | — | ✅=RV8 | ✅=RV8 | ❌ own |
| Registers | Hardware | RAM | RAM | RAM |

## Key Insight:
- Full ISA always costs ~27 chips (gates or microcode — same)
- RAM registers save ~10 chips (RV8-R = 17 chips!)
- Reduced ISA (drop AND/OR/XOR) saves more (RV8-GR = 19 chips, no microcode)
- Serial ALU doesn't save enough (archived RV8-S)

## Folder Structure

```
/home/jo/kiro/RV8/
├── RV8/        27 chips, proven, microcode, Verilog 8/8 pass
├── RV8R/       17 chips, RAM regs, microcode, fewest+full ISA
├── RV8G/       27 chips, no microcode, full ISA, fastest
├── RV8GR/      19 chips, no microcode, reduced ISA, cheapest games
├── Programmer/ ESP32 + TXB0108 (works with all)
├── Old_Design/ Archived (RV8-G, RV8-S, RV808, RV801, original)
├── Reference/  Gigatron, SAP-1, Nand2Tetris
└── README.md
```

## What's Working:
- RV8 microcode-driven Verilog: 8/8 tests pass
- RV8 microcode generator (Python): generates Flash .bin
- Programmer board: designed (ESP32 + TXB0108 + firmware + tools)
- All WiringGuides: bus-centric format (RV8-Bus external + IBUS internal)
- Understand by Module: English + Thai (RV8, RV8-G)

## Next Steps:
1. Decide which variant to build first
2. Complete instruction trace for chosen variant
3. Build Programmer board physically
4. Write assembler
5. Build CPU on breadboard
6. BASIC interpreter
