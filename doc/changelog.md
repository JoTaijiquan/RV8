# RV8 Changelog

## v1.2 (2026-05-12)
- KiCad schematic: labels at pin endpoints, 364/364 nets connected
- Yosys circuit diagrams (SVG) for all modules
- All .v files converted to standard Verilog-2001/2005
- Simulation labs verified (labs 1-7 pass, lab 8 full CPU pass)

## v1.1 (2026-05-12)
- KiCad CPU board schematic (27 chips, 390 nets)
- Simulation testbenches for all 8 labs (Icarus Verilog)
- Lab sheets (8 labs): step-by-step CPU build with test procedures
- Build guide (doc/08_build_guide.md)
- SYNC signal added to circuit doc and 40-pin connector

## v1.0 (2026-05-11)
- 69 tests ALL PASS: complete ISA verified
- CPU board: 23 CPU chips + 4 system = 27 total
- 40-pin expansion connector
- Trainer board: ESP32 NodeMCU + 74HCT245 level shifting
- Cross-assembler (tools/rv8asm.py)
- Pico in-circuit ROM programmer
- Fibonacci demo runs correctly

## v0.5 (2026-05-10)
- Verilog implementation complete (rv8_cpu.v)
- Synthesizable structural version (rtl/rv8_synth.v)
- Architecture verified: 17 states, 23 chips, 730 gates
- ISA: 68 instructions, direct-encoded opcodes

## v0.1 (2026-05-09)
- Initial requirements and ISA design
- RV801 ultra-minimal spec (8 chips)
