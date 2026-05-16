# RV8-W — Full ISA, No Microcode, RAM Registers

**27 logic chips. Full RISC-V ISA. No microcode. 1.7 MIPS @ 10 MHz.**

| Spec | Value |
|------|-------|
| Logic chips | 27 |
| Total | 29 |
| ISA | Full (35 instructions, same as RV8) |
| Speed | 1.7 MIPS @ 10 MHz |
| Registers | 8 in RAM |
| Control | **None** — instruction bits drive hardware directly |
| Binary compatible | ✅ Same programs as RV8 |
| Pro | **Full ISA + no microcode + fastest** |
| Con | Same chip count as RV8, more complex wiring |

---

## Chip List (27 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1 | 74HC574 | AC (accumulator, hardwired to ALU A) |
| U2 | 74HC574 | IR_HIGH (control byte) |
| U3-U4 | 74HC283 ×2 | ALU adder (8-bit) |
| U5-U6 | 74HC86 ×2 | XOR (SUB + XOR instruction) |
| U7-U8 | 74HC574 ×2 | IR_LOW + spare |
| U9 | 74HC541 | AC → IBUS buffer |
| U10 | 74HC245 | Bus buffer (IBUS ↔ RAM) |
| U11-U12 | 74HC157 ×2 | AC D-input mux |
| U13 | 74HC157 | Address mux low |
| U14 | 74HC74 | Flags + state |
| U15-U18 | 74HC161 ×4 | PC (16-bit counter) |
| U19 | 74HC541 | PC → IBUS buffer (for JAL) |
| U20-U21 | 74HC08 ×2 | AND operation (8-bit) |
| U22-U23 | 74HC32 ×2 | OR operation (8-bit) |
| U24-U25 | 74HC157 ×2 | ALU A mux (AC vs PC) |
| U26-U27 | 74HC157 ×2 | Result mux (ADD/AND/OR/XOR select) |
| — | SST39SF010A | Program ROM |
| — | 62256 | RAM (includes registers $00-$07) |

**= RV8-WR (19 chips) + 8 chips for AND/OR/relative branch.**
