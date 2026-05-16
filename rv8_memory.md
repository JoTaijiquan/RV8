# RV8 Project — Session Memory

**Last updated**: 2026-05-17 00:17

---

## Focus: RV8-GR (ready for physical build!)

### What's done:
- ✅ Design (21 chips, no microcode, RAM registers)
- ✅ ISA (21 instructions, ~80% RV8 compatible, XOR free)
- ✅ Verilog (11/11 unit tests + assembly integration test)
- ✅ Assembler (rv8gr_asm.py)
- ✅ WiringGuide (bus-centric, verified)
- ✅ Instruction trace (verified 21 chips)
- ✅ Understand by Module
- ✅ Bank switch design (for Trainer board, future)
- ✅ VCD waveform support

### What's next:
- ⬜ Order parts (~฿575)
- ⬜ Build Programmer board (ESP32 + TXB0108)
- ⬜ Build RV8-GR on breadboard
- ⬜ First program running on real hardware

---

## All Variants (final, traced):

| | RV8 | RV8-R | RV8-G | RV8-GR |
|--|:---:|:---:|:---:|:---:|
| Logic chips | 27 | 18 | 28 | **21** |
| Total | 29 | 21 | 30 | **23** |
| Verilog | ✅ 8/8 | ⬜ | ⬜ | **✅ 11/11** |
| Assembler | ⬜ | ⬜ | ⬜ | **✅** |
| Ready to build | ⬜ | ⬜ | ⬜ | **✅** |

---

## Key Design Decisions:
- Bank switch on Trainer board (CPU stays 21 chips)
- Registers in RAM $0000-$0007 (data path never bank-switched)
- XOR instruction free (reuse SUB XOR chips)
- 3-cycle execution (fetch ctrl, fetch operand, execute)
- Control byte bits directly drive hardware (no lookup)
- ~80% compatible with RV8 ISA (missing AND/OR/SRL only)

## Folder Structure:
```
RV8/
├── RV8/     27 chips, microcode (proven)
├── RV8R/    18 chips, microcode, RAM regs
├── RV8G/    28 chips, no microcode, full ISA
├── RV8GR/   21 chips, no microcode, READY TO BUILD ←
├── Programmer/
├── Old_Design/
└── Reference/
```
