# RV8 Project — Changelog

## 2026-05-16 — Final Family

### RV8-R v0.1
- 17 logic chips, full ISA, RAM registers, microcode
- Binary compatible with RV8

### RV8-WF v0.1
- 27 logic chips, full ISA, no microcode, RAM registers
- Binary compatible with RV8, fastest (1.7 MIPS)

### RV8-WR v0.1
- 19 logic chips, reduced ISA (20 instr), no microcode, RAM registers
- Own ISA (not compatible), cheapest that plays games

### RV8 v0.5
- 27 logic chips, full ISA, hardware registers, microcode
- Microcode-driven Verilog working (8/8 tests pass)
- WiringGuide (bus-centric format)
- Understand by Module (English + Thai)

### Archived
- RV8-S (15 chips, too slow)
- RV8-G (32 chips honest, broken)

---

## 2026-05-15

### RV8 v0.1-v0.4
- Initial design through verification
- Microcode generator + microcode-driven Verilog

---

## 2026-05-14
- Programmer board complete (ESP32 + TXB0108)
