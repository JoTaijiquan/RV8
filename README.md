# RV8: Minimal 8-bit CPU — Accumulator-based, RISC-inspired

Build a real computer from 74HC chips on breadboards.

## Project Structure

```
RV8/
├── CPU/            ← CPU board (26 chips) — DONE
├── Trainer/        ← Trainer board (SBC style) — in progress
├── Computer/       ← Full PC board — planned
├── Rom/            ← System ROM (BASIC + monitor) — planned
├── Reference/      ← Study designs (6502, RISC-V)
└── rv8_cpu.v       ← Main Verilog (top-level)
```

## CPU Board (26 chips)

| Parameter | Value |
|-----------|-------|
| Data width | 8-bit |
| Address space | 16-bit (64KB) |
| Instructions | 68 (fixed 2-byte), 69 tests pass |
| Registers | 7 (c0, sp, a0, pl, ph, t0, pg) |
| CPU chips | 23 (74HC series) |
| Board total | 26 chips (23 CPU + address decode + ROM + RAM) |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB), on-board crystal |

## System Overview (4 boards)

```
┌──────────────────────────────────────────────┐
│  CPU Board (26 chips, self-contained)         │
│  Crystal on-board, always free-running        │
└───────────────────────┬──────────────────────┘
                        │ RV8-Bus (40-pin)
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Programmer  │ │   Trainer    │ │  PC Board    │
│  ESP32       │ │  Clock ovr.  │ │  SD, UART    │
│  ROM flash   │ │  Step/LEDs   │ │  GPIO        │
│  UART term   │ │  SBC style   │ │  Full system │
└──────────────┘ └──────────────┘ └──────────────┘
```

| Board | Role |
|-------|------|
| **CPU** | The computer — runs standalone |
| **Programmer** | Flash ROM + terminal (cheapest host) |
| **Trainer** | Clock override, step, LEDs, 7-seg, SD, keyboard, PS/2 |
| **PC Board** | Expanded I/O, storage, OS-capable |

## Quick Start

```bash
# Simulate the CPU
cd CPU/sim && make all

# Assemble a program
python3 CPU/tools/rv8asm.py CPU/programs/fib.asm -f bin -o fib.bin

# View schematic
xdg-open CPU/doc/diagrams/rv8_cpu_schematic.pdf
```

## Documentation

12 lab sheets (Thai + English) covering the full 68-instruction ISA:

| Labs | Content |
|------|---------|
| 1–8 | Hardware build (clock → control unit) |
| 9–12 | Full ALU, stack, addressing modes, interrupts |

See `CPU/doc/` for full documentation.

## Status

| Board | Status | Folder |
|-------|:------:|--------|
| CPU (26 chips) | ✅ Designed + simulated | `CPU/` |
| Programmer | 🔧 Design done | — |
| Trainer (SBC) | 🔧 Design done | `Trainer/` |
| Full PC | ⬜ Planned | `Computer/` |
| System ROM (BASIC) | ⬜ Planned | `Rom/` |
