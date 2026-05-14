# RV8-G: Pure Gates 8-bit CPU Family

Build a real computer from 74HC chips. **No EEPROM. No microcode. Pure logic gates.**

## CPU Variants

| | RV8-G | RV808-G |
|--|:---:|:---:|
| **Chips** | 23 | **20** |
| **Architecture** | Von Neumann (shared bus) | Harvard (internal ROM) |
| **Instructions** | 25 | 22 |
| **Control** | Pure gates (5 chips) | Pure gates (5 chips) |
| **MIPS @ 10 MHz** | 2.5 | **3.0** |
| **Run BASIC** | ✅ | ✅ |
| **Play games** | ✅ | ✅ |
| **Needs programmer** | No (only ROM) | No (only ROM) |
| **Breadboards** | 3 | 2-3 |
| **Cost** | ~$12 | ~$10 |

## The Constraint

> No EEPROM for control. No GAL/PAL. No microcode.
> Opcode bits ARE control signals — wired directly to hardware.
> If you can wire a breadboard, you can build a computer.

## Project Structure

```
RV8/
├── RV8G/           ← RV8-G (23 chips, shared bus, gates-only)
├── RV808G/         ← RV808-G (20 chips, Harvard, gates-only)
├── Programmer/     ← ESP32 programmer board (flash ROM + terminal)
├── Trainer/        ← Trainer board (step, LEDs, keyboard)
├── Old_Design/     ← Archived: RV8(26), RV801(9), RV808(23) — need EEPROM
├── CHANGELOG.md
├── HISTORY.md
└── README.md
```

## Quick Start

```bash
# Simulate RV8-G
cd RV8G && iverilog -o tb rv8g_cpu.v tb/tb_rv8g_cpu.v && vvp tb

# Flash a program (with Programmer board)
python3 Programmer/tools/rv8flash.py /dev/ttyUSB0 program.bin

# Terminal mode
python3 Programmer/tools/rv8term.py /dev/ttyUSB0
```

## Which to build?

| Your goal | Build |
|-----------|-------|
| Understand shared-bus CPU | **RV8-G** (23 chips, pointer addressing) |
| Minimum chips, fastest | **RV808-G** (20 chips, page:offset) |

## Status

| Item | Status |
|------|:------:|
| RV8-G Verilog (17/17 pass) | ✅ |
| RV8-G control trace (proven) | ✅ |
| RV808-G design doc | ✅ |
| RV808-G Verilog | ⬜ |
| Programmer board | ✅ |
| Assembler | ⬜ |
| Build guide (labs) | ⬜ |
| BASIC interpreter | ⬜ |
| Breadboard build | ⬜ |

## The Philosophy

> **RV8-G**: A computer needs no programmable logic — just gates, wires, and ROM for your program.
