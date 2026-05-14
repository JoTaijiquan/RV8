# RV8 Project — Development History

---

## Day 1-4 (2026-05-10 to 2026-05-13) — Original Designs

- Designed RV8 (26 chips, 68 instructions, EEPROM microcode)
- Designed RV808 (23 chips, 67 instructions, Harvard, EEPROM)
- Designed RV801-A/B (8-9 chips, bit-serial)
- Full Verilog models, testbenches, 12 labs, Thai+English docs
- KiCad schematics, assembler, programmer board
- All archived in Old_Design/

## Day 5 (2026-05-14) — Programmer Board + Agents

- Programmer board complete: ESP32 + TXB0108 level shifters
- Created 5 specialized agents (lead, rtl, docs, hw, sw)
- SYNC pin added to 40-pin bus

## Day 6 (2026-05-15) — Gates-Only Redesign

### Key realization:
The original RV8/RV808 designs claim "no microcode" but actually need EEPROM
for control signal generation (68 instructions × 17 states = too complex for gates).

### Decision: redesign from scratch with hard constraint:
**No EEPROM. No programmable logic. Pure 74HC gates only.**

### RV8-G designed (23 chips, Von Neumann):
- 25 instructions (minimum viable for BASIC + games)
- Opcode bits wire directly to control points — zero decode logic
- 4-state machine (2 flip-flops, ripple counter)
- Control fits in: 1×138 + 2×74 + 1×08 + 1×32 (proven)
- Verilog model: 17/17 tests pass
- 2.5 MIPS @ 10 MHz

### RV808-G designed (20 chips, Harvard):
- Same ISA philosophy, Harvard optimization
- ROM internal (no address mux needed), page:offset for RAM
- S3-skip: 3 cycles for non-memory instructions
- 3.03 MIPS @ 10 MHz
- Fewest chips in the family that still runs BASIC

### Project restructured:
- Old designs (RV8, RV801, RV808) → Old_Design/
- Active focus: RV8-G (23 chips) + RV808-G (20 chips)

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| 2026-05-10 | Project started |
| 2026-05-11 | RV8 Verilog 69/69 pass |
| 2026-05-12 | KiCad, 12 labs, full toolchain |
| 2026-05-13 | RV808 designed (44/44 pass) |
| 2026-05-14 | Programmer board complete |
| 2026-05-15 | **RV8-G family: pure gates, no EEPROM, 20-23 chips** |
