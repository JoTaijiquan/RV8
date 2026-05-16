# RV8 Project — Development History

---

## Day 1-4 (2026-05-10 to 2026-05-13)
- Designed RV8 (68 instr, accumulator, EEPROM) — later found unbuildable
- Designed RV808 (Harvard, paged) — incompatible with shared-bus ecosystem
- Designed RV801 (bit-serial, 9 chips) — too slow for BASIC
- Full Verilog, labs, Thai docs — all archived in Old_Design/

## Day 5 (2026-05-14)
- Programmer board complete (ESP32 + TXB0108)
- Created 5 specialized agents

## Day 6 (2026-05-15) — The Redesign

### Key realizations:
1. Original RV8 needs EEPROM for control (can't fit 68 instr decode in gates)
2. WiringGuide verification proved RV8 unbuildable as documented (~31 chips honest)
3. "Pure gates" (RV8-G) costs 27 chips — same as EEPROM version
4. RISC-V style (register-register) eliminates need for complex addressing modes

### RV8-G designed (pure gates):
- 27 chips, 30 instructions, 34/34 tests pass
- No EEPROM needed — opcode bits wire directly to control
- 2.5 MIPS @ 10 MHz

### RV802 designed (RISC-V + Flash microcode):
- 25 logic chips (27 total with ROM+RAM)
- 8 general-purpose registers, 35 instructions
- Single-bus architecture: simple hardware, microcode sequences everything
- SST39SF010A Flash (70ns, PDIP-32) for control
- 3.0 MIPS @ 10 MHz
- WiringGuide verified: buildable, no bus conflicts, timing OK

### Decision: two active designs
- **RV802**: Best performance, fewest chips, RISC-V style (needs Flash programmer)
- **RV8-G**: No programmer needed, pure educational value (more chips, slower)

---

## Day 7 (2026-05-16) — Verification & Truth

### RV802 verified:
- WiringGuide address bus conflict found and fixed (PC→574 with /OE)
- Understand_by_Module.md created (6 modules for students)
- Honest count: 25 logic + ROM + RAM = 27 packages

### RV8-G deep verification:
- ISA vs hardware conflict analysis revealed fundamental issues:
  - AND/OR/XOR impossible (adder can't do logic ops)
  - No data path for LI/LB to bypass ALU
  - No path for a0 → data bus (store operations)
- Fixing requires 3+ more chips → 29+ total
- **Pure gates costs MORE chips than microcode for same capability**

### Key insight: the three approaches
```
Pure gates (RV8-G):     29+ chips, limited ISA, routing problems
Microcode (RV802):      25 chips, rich ISA, verified buildable
Wide ROM (Gigatron):    17 chips, rich ISA, 2× code size, fastest
```

### RV802-W designed (wide instruction, accumulator):
- 24 logic chips, no microcode, no step counter
- 16-bit instruction: control byte + operand in one ROM word
- Accumulator (a0) hardwired to ALU A — eliminates mux problem
- 1 cycle per ALU instruction = 8 MIPS @ 8 MHz
- RISC-V naming (ADD a0,a0,rs / BEQ a0,zero,off)
- Gigatron-proven approach with RISC-V presentation

### Conclusion:
Three viable designs, each with clear trade-offs:
- **RV802** (27 logic, microcode): RISC-V register-register, 2.17 MIPS, most flexible
- **RV802-W** (24 logic, wide ROM): RISC-V naming + accumulator, 8 MIPS, fastest
- **RV8-G** (26 logic, pure gates): no programmable logic, 2.5 MIPS, educational

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| 2026-05-10 | Project started |
| 2026-05-11 | Original RV8 Verilog 69/69 pass |
| 2026-05-13 | RV808 designed (44/44 pass) |
| 2026-05-14 | Programmer board complete |
| 2026-05-15 | RV802 + RV8-G designed, verified |
| 2026-05-16 | **Deep verification: RV8-G has routing issues, RV802 confirmed best** |
