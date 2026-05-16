# RV8-WR — Reduced ISA, No Microcode, RAM Registers

**19 logic chips. No microcode. Plays games. Cheapest usable build.**

| Spec | Value |
|------|-------|
| Logic chips | 19 |
| Total | 21 |
| ISA | Reduced (20 instructions, own encoding) |
| Speed | 1.7 MIPS @ 10 MHz |
| Registers | 8 in RAM |
| Control | **None** — instruction bits drive hardware directly |
| Binary compatible | ❌ Own ISA (not compatible with RV8) |
| Pro | **Fewest chips that plays games, no microcode** |
| Con | No AND/OR/XOR, no relative branch, own assembler needed |
