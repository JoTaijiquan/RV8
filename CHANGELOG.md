# RV8 Project — Changelog

---

## RV802 (25 logic chips, RISC-V style, Flash microcode)

### v0.3 — 2026-05-16
- Address bus conflict found and fixed (PC as 574 + address latches)
- Understand_by_Module.md (6 modules, analogies, debug checklists)
- WiringGuide rewritten in JSON format (verified, no conflicts)
- Honest speed: 2.17 MIPS @ 10 MHz (PC increment via ALU costs 1 step)

### v0.2 — 2026-05-15
- Verilog model: rv802_cpu.v (19/21 tests pass, BRA+r3 minor fix pending)
- WiringGuide: verified buildable, 25 logic chips, no bus conflicts, 10MHz timing OK
- JSON-style WiringGuide added (pin-by-pin format)
- Honest chip count: 25 logic + ROM + RAM = 27 packages (was claimed 23)

### v0.1 — 2026-05-15
- Initial design: RISC-V inspired, 8 registers, single-bus, Flash microcode
- ISA: 35 instructions (4 classes: ALU reg, immediate, memory, control)
- Target: 3.0 MIPS @ 10 MHz

---

## RV8-G (26+ logic chips, accumulator, pure gates)

### v0.4 — 2026-05-16
- Deep ISA vs hardware verification: found AND/OR/XOR impossible, data routing gaps
- Fixed pl to full 8-bit (2× 74HC161)
- Honest count: 26 logic + ROM + RAM = 28 (without logic ops fix)
- With full fix: 29+ chips needed — more than RV802
- Conclusion: pure gates approach is self-defeating for rich ISA

### v0.3 — 2026-05-15
- Honest chip count: 27 (was claimed 23-24, WiringGuide verification proved more needed)
- 30 instructions, 34/34 tests pass
- Branch encoding: opcode[4:3]=flag, opcode[5]=invert (no 74HC151 needed)
- 74HC139 dual decoder for class + register select

### v0.1 — 2026-05-15
- Initial design: pure gates, no EEPROM, opcode bits = control wires

---

## Programmer Board

### v1.0 — 2026-05-14
- ESP32 NodeMCU + 3× TXB0108 level shifters
- PROG mode (flash ROM) + RUN mode (UART terminal)

---

## Project Restructure — 2026-05-15

- Original RV8 (68 instr, accumulator) → Old_Design/ (unbuildable as documented)
- RV801, RV808 → Old_Design/
- Active: RV802 (RISC-V, Flash) + RV8-G (pure gates)
- Key lesson: simple hardware + smart microcode > complex hardware
