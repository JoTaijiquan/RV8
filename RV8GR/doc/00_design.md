# RV8-GR — Design Document

**21 logic chips. No microcode. Reduced ISA. Cheapest that plays games.**

---

## Architecture

- Accumulator (AC) hardwired to ALU A
- Registers in RAM ($00-$07)
- 3-cycle execution (fetch control, fetch operand, execute)
- Control byte bits directly drive hardware (no lookup table)
- 8-bit parallel ALU (adder + XOR)
- SST39SF010A program ROM (8-bit, 70ns)

## Chip List (21 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1 | 74HC574 | AC (accumulator) |
| U2 | 74HC574 | IR_HIGH (control byte) |
| U3-U4 | 74HC283 ×2 | ALU adder (8-bit) |
| U5-U6 | 74HC86 ×2 | XOR (SUB + XOR instruction) |
| U7 | 74HC157 | Address mux A[7:4] |
| U8 | 74HC574 | IR_LOW (operand) |
| U9 | 74HC541 | AC → IBUS buffer |
| U10 | 74HC245 | Bus buffer (IBUS ↔ RAM) |
| U11-U12 | 74HC157 ×2 | AC D-input mux |
| U13 | 74HC157 | Address mux A[3:0] |
| U14 | 74HC161 | State counter (3 states) |
| U15-U18 | 74HC161 ×4 | PC (16-bit) |
| U19 | 74HC541 | PC → IBUS buffer (JAL) |
| U20 | 74HC74 | Flags (Z) |
| U21 | 74HC32 | OR gates (derived signals) |
| — | SST39SF010A | Program ROM |
| — | 62256 | RAM (registers + data) |

## Performance

| Clock | Cycles/instr | MIPS |
|:-----:|:------------:|:----:|
| 3.5 MHz | 3 | 1.17 |
| 10 MHz | 3 | **3.3** |

## Verified: Verilog 11/11 pass, instruction trace done, WiringGuide complete.
