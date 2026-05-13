# RV8: Minimal 8-bit CPU — Accumulator-based, RISC-inspired

Build a real computer from 74HC chips on breadboards.

## Project Structure

```
RV8/
├── RV8/            ← RV8 CPU board (26 chips) — DONE
├── RV808/          ← RV808 CPU board (23 chips) — design phase
├── Trainer/        ← Trainer board (SBC style) — in progress
├── Computer/       ← Full PC board — planned
├── Rom/            ← System ROM (BASIC + monitor) — planned
├── Reference/      ← Study designs (6502, RISC-V)
└── README.md
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
cd RV8/sim && make all

# Assemble a program
python3 RV8/tools/rv8asm.py RV8/programs/fib.asm -f bin -o fib.bin

# View schematic
xdg-open RV8/doc/diagrams/rv8_cpu_schematic.pdf
```

## Documentation

12 lab sheets (Thai + English) covering the full 68-instruction ISA:

| Labs | Content |
|------|---------|
| 1–8 | Hardware build (clock → control unit) |
| 9–12 | Full ALU, stack, addressing modes, interrupts |

See `RV8/doc/` for full documentation.

## Status

| Board | Status | Folder |
|-------|:------:|--------|
| CPU (26 chips) | ✅ Designed + simulated | `RV8/` |
| RV808 (23 chips) | 🔧 Design phase | `RV808/` |
| Programmer | 🔧 Design done | — |
| Trainer (SBC) | 🔧 Design done | `Trainer/` |
| Full PC | ⬜ Planned | `Computer/` |
| System ROM (BASIC) | ⬜ Planned | `Rom/` |
