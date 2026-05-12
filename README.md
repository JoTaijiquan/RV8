# RV8: Minimal 8-bit CPU — Accumulator-based, RISC-inspired

Build a real computer from 74HC chips on breadboards.

## Project Structure

```
RV8/
├── CPU/            ← CPU board (27 chips) — DONE
├── Trainer/        ← Trainer board (~10 chips + ESP32) — in progress
├── Computer/       ← Full PC board (~17 chips, video+keyboard) — planned
├── rom/            ← System ROM (BASIC + monitor) — planned
├── Reference/      ← Study designs (6502, RISC-V)
└── rv8_cpu.v       ← Main Verilog (top-level)
```

## CPU Board (27 chips)

| Parameter | Value |
|-----------|-------|
| Data width | 8-bit |
| Address space | 16-bit (64KB) |
| Instructions | 68 (fixed 2-byte), 69 tests pass |
| Registers | 7 (c0, sp, a0, pl, ph, t0, pg) |
| CPU chips | 23 (74HC series) |
| System total | 27 chips (+ ROM + RAM + decode + clock) |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |

## System Overview

```
┌─────────────────────────────────┐
│  CPU Board (27 chips)           │  ← You are here
└───────────────┬─────────────────┘
                │ 40-pin connector
    ┌───────────┼───────────┐
    ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Trainer │ │Full PC  │ │ Custom  │
│ ~$23    │ │ ~$75    │ │         │
└────┬────┘ └────┬────┘ └────┬────┘
     └───────────┴───────────┘
         40-pin Bus Slot
         (ROM/RAM/I/O cards)
```

## Quick Start

```bash
# Simulate the CPU
cd CPU/sim && make all

# Assemble a program
python3 CPU/tools/rv8asm.py CPU/programs/fib.asm -f bin -o fib.bin

# View schematic
xdg-open CPU/doc/diagrams/rv8_cpu_schematic.pdf
```

## Status

| Board | Status | Folder |
|-------|:------:|--------|
| CPU (27 chips) | ✅ Designed + simulated | `CPU/` |
| Trainer (~10 + ESP32) | 🔧 Basic design done | `Trainer/` |
| Full PC (~17 chips) | ⬜ Planned | `Computer/` |
| System ROM (BASIC) | ⬜ Planned | `rom/` |
