# RV8 Project — Changelog

---

## RV8-S (20 logic chips, serial ALU, Flash microcode)

### v0.1 — 2026-05-16
- Initial design + WiringGuide (20 chips, carry OR issue noted)
- 1.0 MIPS @ 10 MHz, same RISC-V ISA as RV8
- RV8-Bus compatible

---

## RV8-W (25 logic chips, accumulator, no microcode)

### v0.2 — 2026-05-16
- WiringGuide created and verified (25 chips, not 24)
- AC needs 74HC541 buffer to drive IBUS (+1 chip vs claimed)
- AND/OR/XOR not possible (adder only — same problem as RV8-G)
- 6 instruction traces verified
- Honest speed: 2.5 MIPS @ 5 MHz

### v0.1 — 2026-05-16
- Initial design: accumulator + 2-cycle fetch, RISC-V naming

---

## RV8 (27 logic chips, RISC-V reg-reg, Flash microcode)

### v0.4 — 2026-05-16
- WiringGuide FIXED: added U26 (step counter) + U27 (2nd Flash)
- Honest count: 27 logic + ROM + RAM = 29 packages
- All control signals traced with source chip.pin

### v0.3 — 2026-05-16
- Address bus conflict fixed (PC as 574 + address latches)
- Understand_by_Module.md created
- ISA aligned to RISC-V (BEQ rs1,rs2 style)

### v0.2 — 2026-05-15
- Verilog model (19/21 pass)
- Initial WiringGuide

### v0.1 — 2026-05-15
- Initial design: RISC-V inspired, 8 registers, single-bus

---

## Programmer Board

### v1.0 — 2026-05-14
- ESP32 NodeMCU + 3× TXB0108 level shifters
- PROG mode (flash ROM) + RUN mode (UART terminal)
