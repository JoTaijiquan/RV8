# RV8 Changelog

## v1.2 — 2026-05-12 17:50
- KiCad schematic optimized: labels at pin endpoints, 364/364 nets connected
- Yosys circuit diagrams (SVG) for all 5 modules
- All .v files converted to standard Verilog-2001/2005
- KiCad verified: 18/18 design checks pass
- Repo reorganized: clean doc/ structure, historical docs to reference/

## v1.1 — 2026-05-12 02:35
- Lab sheets: 8 labs with simulation-first workflow
- Simulation testbenches (Icarus Verilog, labs 1-8 all pass)
- Build guide: 8 steps, module-by-module with tests
- KiCad CPU board schematic (27 chips, 390 nets)
- SYNC signal added to circuit doc and 40-pin connector
- Beginner-friendly sim README

## v1.0 — 2026-05-12 01:14
- CPU board finalized: 23 CPU + 4 system = 27 chips
- 40-pin DIP expansion connector
- Trainer board: ESP32 NodeMCU + 74HCT245 level shifting
- Pico in-circuit ROM programmer + bootloader
- Branding: "Minimal 8-bit CPU — Accumulator-based, RISC-inspired"

## v0.9 — 2026-05-11 23:54
- Modular rv8_cpu.v (top-level with sub-modules)
- RV801 docs separated to rv801/

## v0.8 — 2026-05-11 04:05
- Fibonacci demo runs correctly (0,1,1,2,3,5,8,13,21,34,55)
- Circuit diagram: all 27 chips with pin connections
- Cross-assembler: Python, Intel HEX output, all 68 opcodes
- Synthesizable structural version (rv8_synth.v)

## v0.5 — 2026-05-11 03:22
- **69 tests ALL PASS** — complete ISA verified
- 68 instructions: ALU, load/store, branch, skip, shift, pointer, system
- TRAP, RTI, NMI, IRQ, constant generator all working
- Architecture: 17 states, 23 CPU chips, ~730 gates

## v0.3 — 2026-05-11 02:46
- First working CPU: 9 tests pass
- Verilog implementation compiles and simulates
- Basic instructions: LI, ADDI, SUBI, BNE, SB/LB

## v0.1 — 2026-05-10 20:58
- Initial requirements and ISA design
- Direct-encoded opcodes, no microcode
- Target: 20 CPU chips (later revised to 23)
