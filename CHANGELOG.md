# RV8 Project — Changelog

---

## RV8 CPU (26 chips, parallel)

### v1.8 — 2026-05-14
- Programmer board complete: ESP32 + TXB0108 level shifters (~$10)
- ESP32 firmware + PC tools (rv8flash.py, rv8term.py)
- SYNC pin (pin 37) on 40-pin bus
- Merged programmer files, created 5 specialized agents

### v1.7 — 2026-05-13
- Board redesign: 27→26 chips (removed clock mux)
- 4-board system: CPU, Programmer, Trainer, PC Board
- Single-step moved to Trainer board

### v1.6 — 2026-05-13
- Expanded to 12 labs (full 68-instruction ISA coverage)
- Thai versions for all labs in concise lab-sheet style
- Pin-by-pin wiring tables in build guide

### v1.5 — 2026-05-13
- Fixed rv8_cpu.v: 69/69 tests pass (was broken)
- Major rewrite: instruction decode, ALU, operand timing, interrupts

### v1.4 — 2026-05-12
- RV8-Bus: 40-pin universal backplane
- Project reorganized: CPU/, Trainer/, Computer/, Rom/

### v1.3 — 2026-05-12
- KiCad schematic v3 (data-flow layout)
- Yosys + netlistsvg diagrams
- Docs renumbered 00-08

### v1.2 — 2026-05-12
- KiCad optimized: 364/364 nets connected
- Verilog-2001 standard compliance

### v1.1 — 2026-05-12
- 8 lab sheets with simulation
- KiCad schematic (27 chips, 390 nets)

### v1.0 — 2026-05-12
- CPU board finalized: 27 chips
- 40-pin connector, Trainer board, Pico programmer

### v0.5 — 2026-05-11
- 69 tests ALL PASS — complete ISA verified

### v0.1 — 2026-05-10
- Initial ISA design (68 instructions)

---

## RV808 CPU (23 chips, Harvard)

### v0.3 — 2026-05-13
- Added MOV (12 variants) + JMP pg:imm
- ISA: 67 instructions, 44/44 tests pass

### v0.2 — 2026-05-13
- Full Thai build guide with pin-level wiring tables
- Chip pinout diagrams, power table

### v0.1 — 2026-05-13
- Initial design: Harvard, 23 chips, page:offset
- Verilog model: 40/40 tests pass
- Circuit diagram, build guide (8 labs)

---

## Programmer Board

### v1.0 — 2026-05-14
- ESP32 NodeMCU + 3× TXB0108 level shifters
- PROG mode (flash ROM) + RUN mode (UART terminal)
- Firmware, PC tools, Thai docs complete
