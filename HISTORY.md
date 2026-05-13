# RV8 Project — Development History

---

## Day 1 (2026-05-10) — ISA Design

- Project started: requirements + ISA design
- Decisions: 8-bit, fixed 2-byte, accumulator, hardwired control, 5V USB
- Rejected: PC-relative, hardware multiply, DMA, FPU, variable-length
- Target: 20 CPU chips (later revised)

## Day 2 (2026-05-11) — Verilog + Verification

- ISA v5: 68 instructions, direct-encode, const-gen, conditional skip
- RV801 ultra-minimal variant spec (8-9 chips, bit-serial)
- Architecture: datapath, FSM (17 states), chip mapping → 23 chips
- Verilog implementation: rv8_cpu.v
- **69 tests ALL PASS** — complete ISA verified
- Cross-assembler (rv8asm.py), circuit diagram, Fibonacci demo

## Day 3 (2026-05-12) — Hardware + Labs

- KiCad schematic (27 chips, 390 nets, 18/18 checks pass)
- 8 lab sheets with simulation testbenches
- Build guide (module-by-module)
- Pico programmer + bootloader + UART
- Trainer board design (ESP32 + 74HCT245)
- 40-pin RV8-Bus expansion connector
- Project reorganized: CPU/, Trainer/, Computer/, Rom/
- Yosys + netlistsvg circuit diagrams
- CPU netlists: Verilog, JSON, EDIF, BLIF, SPICE

## Day 4 (2026-05-13 morning) — CPU Fix + Lab Expansion

- **rv8_cpu.v fully fixed**: 69/69 tests pass (was broken)
- Root causes found: decode, ALU width, operand timing, branch offset, PUSH, RTI
- Expanded to 12 labs covering full 68-instruction ISA
- Thai versions for all labs (concise lab-sheet style for middle school)
- Pin-by-pin wiring tables in build guide

## Day 5 (2026-05-13 afternoon) — Board Redesign + RV808

- Board redesign: 27→26 chips (removed clock mux U25)
- 4-board system: CPU, Programmer, Trainer, PC Board
- Single-step moved to Trainer board (CPU always free-running)
- Updated all docs (requirements, architecture, circuit, build guide, labs)

### RV808 Design (2026-05-13 evening)

- Idea: 8-bit multiplexed bus matching ISA philosophy
- Explored: multiplexed bus, page register, Harvard, pure 256-byte
- Selected: Harvard (internal ROM fetch + paged data bus)
- Confirmed: BASIC + games feasible at 10 MHz
- Deep design: ISA encoding, state machine, datapath, memory map
- Decisions: 4 registers, page:offset, code overlay, ROM banking, 4 slots
- Verilog model: rv808_cpu.v (44/44 tests pass)
- Circuit diagram, build guide (8 labs, Thai+English)
- Added MOV (12 variants) + JMP pg:imm
- Final: 23 chips, 67 instructions, ~590 gates

### Programmer Board (2026-05-14 early morning)

- ESP32 NodeMCU + 3× TXB0108 level shifters (~$10)
- PROG mode: flash ROM via address+data lines
- RUN mode: UART terminal bridge via slot I/O
- Firmware (rv8_programmer.ino), PC tools (rv8flash.py, rv8term.py)
- Thai documentation
- Merged old RV8/programmer/ into top-level Programmer/
- SYNC pin (pin 37) added to 40-pin bus
- 5 specialized agents created (lead, rtl, docs, hw, sw)

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| 2026-05-10 | Project started, ISA designed |
| 2026-05-11 | 69/69 Verilog tests pass |
| 2026-05-12 | KiCad schematic, 8 labs, full toolchain |
| 2026-05-13 | 12 labs, Thai docs, RV808 designed (44/44 pass) |
| 2026-05-14 | Programmer board complete, project fully documented |
