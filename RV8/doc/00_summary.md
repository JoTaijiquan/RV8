# RV8 — Project Summary

**Minimal 8-bit CPU — Accumulator-based, RISC-inspired**

## What Is RV8?

A minimal 8-bit CPU built from 26 discrete chips on breadboards. Designed for students to build, understand, and program.

## Specs

| Parameter | Value |
|-----------|-------|
| Data bus | 8-bit |
| Address bus | 16-bit (64KB) |
| Instructions | 68 (fixed 2-byte, direct-encoded) |
| Registers | 7: c0, sp, a0, pl, ph, t0, pg |
| Flags | Z, C, N + IE |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| CPU chips | 23 (74HC series) |
| CPU board total | 26 chips (23 CPU + NMI latch + ROM + RAM) |
| Control | Hardwired FSM, no microcode |
| Power | 5V USB, <1.3W |

## System Architecture (4 boards)

```
┌──────────────────────────────────────────────────┐
│  CPU BOARD (26 chips, self-contained)             │
│  Crystal on-board, always runs                    │
│  PC → ROM → IR → Control → ALU → Registers      │
└────────────────────────┬─────────────────────────┘
                         │ RV8-Bus (40-pin)
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  PROGRAMMER  │ │   TRAINER    │ │  PC BOARD    │
│  ESP32       │ │  Clock ovr.  │ │  SD, UART    │
│  ROM flash   │ │  Step/LEDs   │ │  GPIO        │
│  UART term   │ │  SBC style   │ │  Full system │
└──────────────┘ └──────────────┘ └──────────────┘
```

## Documents (reading order)

| # | File | Content |
|---|------|---------|
| 00 | summary.md | This file |
| 01 | requirements.md | Design goals and constraints |
| 02 | isa_design.md | ISA design decisions |
| 03 | architecture.md | Datapath, FSM, timing (17 states) |
| 04 | isa_reference.md | All 68 instructions (source of truth) |
| 05 | circuit.md | 26 chips, pin-level connections |
| 06 | build_guide.md | 12-step module-by-module build |
| 07 | changelog.md | Version history |
| 08 | history.md | Detailed development timeline |

## Key Files

```
rv8_cpu.v              — Verilog (modular, 69 tests pass)
rtl/rv8_cpu.v          — Verilog (flat, compact)
doc/labs/              — 12 lab sheets with simulation (Thai+English)
sim/                   — Icarus Verilog testbenches
kicad/rv8_cpu/         — KiCad schematic
tools/rv8asm.py        — Cross-assembler
```

## Status

- ✅ ISA design complete (68 instructions)
- ✅ Verilog verified (69 tests pass)
- ✅ Circuit designed (26 chips, 4-board system)
- ✅ KiCad schematic (364 nets connected)
- ✅ Lab sheets (12 labs, full ISA coverage, Thai+English)
- ✅ Build guide with pin-by-pin wiring tables
- ⬜ Breadboard build
- ⬜ PCB layout
- ⬜ Programmer board
- ⬜ Trainer board
