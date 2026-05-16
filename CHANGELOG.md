# RV8 Project — Changelog

## RV8-GR v1.0 — 2026-05-17
- Verilog model: 11/11 unit tests pass
- Assembler: rv8gr_asm.py (all 21 instructions, labels, .org)
- Assembly integration test: full pipeline verified (asm→bin→CPU→correct results)
- VCD waveform dump for gtkwave
- Full doc set: design, ISA reference, instruction trace, WiringGuide, understand_by_module
- Bank switch design (for Trainer board, future)
- Honest chip count: 21 logic + ROM + RAM = 23 packages

## RV8 v0.5 — 2026-05-16
- Microcode-driven Verilog (8/8 pass)
- Microcode generator (Python)
- WiringGuide (bus-centric, 27 chips)
- Understand by Module (Thai + English)

## RV8-R v0.1 — 2026-05-16
- Design + instruction trace (18 chips verified)
- WiringGuide (bus-centric)

## RV8-G v0.1 — 2026-05-16
- Design + trace verification (28 chips)
- WiringGuide (bus-centric)

## Programmer Board v1.0 — 2026-05-14
- ESP32 + TXB0108 level shifters
- PROG mode + RUN mode (UART terminal)
