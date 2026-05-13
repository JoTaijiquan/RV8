# RV8 Project — Session Memory

**Last updated**: 2026-05-13 21:42

---

## Project Overview

RV8 is a family of minimal 8-bit CPUs built from 74HC logic chips on breadboards. Educational project for middle school students (Thai + English docs).

**Repository**: github.com/JoTaijiquan/RV8
**Location**: `/home/jo/kiro/RV8/`

---

## CPU Variants

| Variant | Chips | Architecture | Speed | Status |
|---------|:-----:|-------------|:-----:|:------:|
| RV801-A | 8 | Bit-serial, EEPROM microcode | 175K instr/s | Spec done |
| RV801-B | 9 | Bit-serial, hardwired | 175K instr/s | Spec done |
| RV8 | 26 | Parallel, Von Neumann | 1.4M instr/s | ✅ Complete |
| RV808 | 23 | Harvard, page:offset | 1.0M instr/s | ✅ Complete |

---

## RV8 (26 chips) — Parallel CPU

- **ISA**: 68 instructions, 2-byte fixed format
- **Registers**: 7 (a0, t0, sp, pg, pl, ph, c0)
- **Bus**: 16-bit address + 8-bit data (40-pin parallel)
- **Verilog**: 69/69 tests pass
- **Docs**: 12 labs (Thai+English), pin-level wiring tables
- **Chip mapping**: U1-U4=PC(161), U5-U6=IR(574), U7-U10=regs(574), U11-U12=ptr(161), U13-U14=ALU(283), U15=XOR(86), U16-U17=addr mux(157), U18=instr decode(138), U19=bus buf(245), U20-U21=flags+state(74), U22=AND(08), U23=OR(32), U24=addr decode(138), ROM, RAM

---

## RV808 (23 chips) — Harvard CPU

- **ISA**: 67 instructions, 2-byte fixed format
- **Registers**: 4 (a0, t0, sp, pg) + constant generator
- **Bus**: 8-bit paged data (40-pin, 20 active + SYNC)
- **Architecture**: Internal ROM fetch (no bus penalty) + page:offset RAM access
- **Memory**: 32KB ROM (code, internal) + 32KB RAM (data, paged 128×256)
- **Code from RAM**: overlay at $4000-$7FFF via RAM_EXEC bit (0 extra chips)
- **ROM banking**: 64KB+ via spare flip-flop bits (0 extra chips)
- **Expansion**: 4 pre-decoded slots (pages $80-$FF on external bus)
- **Verilog**: 44/44 tests pass
- **Docs**: 8 labs (Thai+English), pin-level wiring tables
- **Chip mapping**: U1-U4=PC(161), U5-U6=IR(574), U7-U10=regs(574), U11-U12=ALU(283), U13=XOR(86), U14=instr decode(138), U15-U16=flags+state(74), U17=AND(08), U18=OR(32), U19=bus buf(245), U20=page latch(574), U21=addr decode(138), ROM, RAM

---

## Board System (shared across all variants)

| Board | Function | Status |
|-------|----------|:------:|
| CPU board | The computer (self-contained, crystal on-board) | ✅ |
| Programmer | ESP32, PROG/RUN switch, ROM flash + UART terminal | Design done |
| Trainer | Clock override, STEP (via SYNC pin), LEDs, 7-seg, SD, keyboard, PS/2 | Design done |
| PC Board | Expanded I/O, SD, UART, GPIO | Planned |

**40-pin bus** shared by all variants. Pin 37 = SYNC (instruction start pulse).
**Programmer board** works with all CPU variants (RV8, RV801, RV808).

---

## Key Design Decisions

1. **RV8**: Clock on CPU board (crystal, always free-running). Single-step on Trainer board.
2. **RV808**: Harvard fetch (ROM internal, no bus penalty). Page:offset = ISA matches hardware.
3. **All variants**: Same 40-pin bus connector, same Programmer/Trainer boards.
4. **Target audience**: Middle school students. Thai lab-sheet style docs.
5. **Philosophy**: RV801=CPU can be simple. RV8=how CPU works. RV808=how to design one.

---

## Folder Structure

```
/home/jo/kiro/RV8/
├── RV8/            26-chip parallel CPU (complete)
│   ├── rv8_cpu.v   Verilog model
│   ├── tb/         Testbench (69/69)
│   ├── doc/        12 labs + 8 doc files
│   ├── sim/        Simulation testbenches
│   ├── kicad/      Schematic
│   ├── tools/      Assembler (rv8asm.py)
│   └── programs/   Example programs
├── RV801/          8-9 chip bit-serial CPU (spec)
│   ├── 03_rv801_spec.md
│   └── 07_rv801_circuit.md
├── RV808/          23-chip Harvard CPU (complete)
│   ├── rv808_cpu.v Verilog model
│   ├── tb/         Testbench (44/44)
│   └── doc/        8 labs + 6 doc files
├── Trainer/        Trainer board design
├── Computer/       PC board design
├── Rom/            System ROM (BASIC) — planned
├── Reference/      Study designs (6502, RISC-V)
└── README.md       Family comparison + quick start
```

---

## What's Done (Day 1-5)

- Day 1: ISA design, architecture, requirements
- Day 2: KiCad schematic, netlist, simulation
- Day 3: Verilog CPU (rv8_cpu.v), all 69 tests pass
- Day 4: 12 labs, Thai versions, build guide, pin wiring tables
- Day 5: Board redesign (26→26 chips, 4-board system), RV808 design (23 chips, Harvard, 44/44 tests), MOV+JMP added, full docs

---

## Next Steps

- [ ] Build Programmer board (ESP32 + level shifters)
- [ ] Build RV801-B on breadboard (9 chips, quickest physical build)
- [ ] Write rv808asm.py assembler
- [ ] Write BASIC interpreter (in ROM)
- [ ] RV808 PCB design (JLCPCB)
- [ ] Video card (FPGA or ESP32, text 40×25, HDMI)
- [ ] Verilog for RV801
