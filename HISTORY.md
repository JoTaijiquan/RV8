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

## Key Milestones

| Date | Milestone |
|------|-----------|
| 2026-05-10 | Project started |
| 2026-05-11 | Original RV8 Verilog 69/69 pass |
| 2026-05-13 | RV808 designed (44/44 pass) |
| 2026-05-14 | Programmer board complete |
| 2026-05-15 | **RV802 + RV8-G: honest, buildable, verified** |
