# RV8 Project — Changelog

---

## RV8-G (23 chips, Von Neumann, gates-only)

### v0.1 — 2026-05-15
- Initial design: 23 chips, 25 instructions, pure 74HC gates, no EEPROM
- Opcode bits wire directly to control — minimal decode
- Verilog model: rv8g_cpu.v (17/17 tests pass)
- Control signal trace: proven fits in 5 gate chips (1×138 + 2×74 + 1×08 + 1×32)
- 4-state machine (S0-S3), 4 cycles/instruction

---

## RV808-G (20 chips, Harvard, gates-only)

### v0.1 — 2026-05-15
- Initial design: 20 chips, ~22 instructions, pure gates, Harvard fetch
- ROM internal (PC→ROM direct), paged RAM (pg:offset)
- S3-skip optimization: 3 cycles for non-memory instructions
- 3.03 MIPS @ 10 MHz
- Removes address mux (−2 chips) and pointer registers (−1 chip) vs RV8-G

---

## Programmer Board

### v1.0 — 2026-05-14
- ESP32 NodeMCU + 3× TXB0108 level shifters (~$10)
- PROG mode (flash ROM) + RUN mode (UART terminal)
- Firmware, PC tools, Thai docs complete

---

## Project Restructure — 2026-05-15

- Moved RV8, RV801, RV808 (EEPROM designs) to Old_Design/
- Focus shifted to RV8-G family (gates-only, no EEPROM)
- Active variants: RV8-G (23 chips) + RV808-G (20 chips)

---

## Old Designs (archived in Old_Design/)

- RV8 v1.8 (26 chips, 68 instructions, EEPROM control)
- RV808 v0.3 (23 chips, 67 instructions, EEPROM control)
- RV801-A/B (8-9 chips, bit-serial)
