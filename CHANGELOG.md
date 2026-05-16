# RV8 Project — Changelog

## 2026-05-16 — Final Family

### RV8-R v0.1
- 17 logic chips, full ISA, RAM registers, microcode
- Binary compatible with RV8

### RV8-G v0.1
- 27 logic chips, full ISA, no microcode, RAM registers
- Binary compatible with RV8, fastest (1.7 MIPS)

### RV8-GR v0.2 — 2026-05-16
- Verilog model: 11/11 tests pass (LI,ADDI,SUBI,ADD,XOR,MV,BEQ,BNE,loop)
- Full doc set: design, ISA reference, trace, WiringGuide, understand_by_module
- Honest chip count: 21 logic (traced and verified)
- 3-cycle execution, ~3.3 MIPS @ 10 MHz

### RV8 v0.5
- 27 logic chips, full ISA, hardware registers, microcode
- Microcode-driven Verilog working (8/8 tests pass)
- WiringGuide (bus-centric format)
- Understand by Module (English + Thai)

### Archived
- RV8-S (15 chips, too slow)
- Old RV8-G pure gates (32 chips honest, broken)

---

## 2026-05-15

### RV8 v0.1-v0.4
- Initial design through verification
- Microcode generator + microcode-driven Verilog

---

## 2026-05-14
- Programmer board complete (ESP32 + TXB0108)
