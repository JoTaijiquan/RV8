# RV8-R — RAM Registers, Full ISA, Microcode

**18 logic chips. Full RISC-V ISA. Registers in RAM. 1.0 MIPS @ 10 MHz.**

| Spec | Value |
|------|-------|
| Logic chips | 18 |
| Total | 21 (+ ROM + RAM + Flash) |
| ISA | Full (35 instructions, same as RV8) |
| Speed | 1.0 MIPS @ 10 MHz |
| Registers | 8 in RAM ($00-$07) |
| Control | 2× Flash microcode |
| Binary compatible | ✅ Same programs as RV8 |
| Pro | **Fewest chips with full ISA** |
| Con | Needs Flash programmer, slightly slower |

---

## Chip List (17 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U2 | 74HC574 ×2 | IR (opcode + operand) |
| U3 | 74HC574 | ALU B latch |
| U4-U5 | 74HC283 ×2 | ALU adder (8-bit) |
| U6-U7 | 74HC86 ×2 | XOR (SUB invert) |
| U8-U9 | 74HC574 ×2 | PC (low + high, /OE) |
| U10-U11 | 74HC574 ×2 | Address latches (low + high) |
| U12 | 74HC245 | Bus buffer (IBUS ↔ RAM) |
| U13 | SST39SF010A | Microcode Flash #1 |
| U14 | 74HC74 | Flags (Z, C) |
| U15 | 74HC574 | ALU result latch |
| U16 | 74HC161 | Step counter |
| U17 | SST39SF010A | Microcode Flash #2 |
| — | AT28C256 | Program ROM |
| — | 62256 | RAM (includes registers $00-$07) |

**Same as RV8 minus**: 8× register chips (574) + 2× decode chips (138) = −10 chips.
Registers live in RAM at addresses $00-$07.
