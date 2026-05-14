# RV8: Minimal 8-bit CPU Family

Build real computers from 74HC chips on breadboards.

## CPU Variants

| | RV801-B | RV8-G | RV808-G | RV8 | RV808 |
|--|:---:|:---:|:---:|:---:|:---:|
| **Chips** | **9** | 23 | **20** | 26 | 23 |
| **Control** | Hardwired | **Gates** | **Gates** | EEPROM | EEPROM |
| **Architecture** | Bit-serial | Von Neumann | Harvard | Von Neumann | Harvard |
| **Instructions** | 68 | 25 | 22 | 68 | 67 |
| **MIPS @ 10 MHz** | 0.5 | 2.5 | 3.0 | 4.0 | 2.86 |
| **Run BASIC** | ⚠️ slow | ✅ | ✅ | ✅ | ✅ |
| **Needs programmer** | No | **No** | **No** | Yes | Yes |
| **Breadboards** | 1 | 3 | 2-3 | 4 | 3 |
| **Cost** | ~$8 | ~$12 | ~$10 | ~$18 | ~$14 |
| **Best for** | Ultra-minimal | Gates-only shared bus | **Gates-only Harvard** | Full power | Elegant paged |

## Project Structure

```
RV8/
├── RV8/            ← RV8 CPU (26 chips, Von Neumann, EEPROM) — DONE
├── RV801/          ← RV801 CPU (8-9 chips, bit-serial) — spec done
├── RV808/          ← RV808 CPU (23 chips, Harvard, EEPROM) — DONE
├── RV8G/           ← RV8-G CPU (23 chips, Von Neumann, gates-only) — DONE
├── RV808G/         ← RV808-G CPU (20 chips, Harvard, gates-only) — design
├── Programmer/     ← ESP32 programmer board — DONE
├── Trainer/        ← Trainer board (SBC style) — planned
├── Computer/       ← Full PC board — planned
├── Rom/            ← System ROM (BASIC + monitor) — planned
├── Reference/      ← Study designs (6502, RISC-V)
└── README.md
```

## Quick Start

```bash
# Simulate RV8
cd RV8/sim && make all

# Simulate RV808
cd RV808 && iverilog -o tb rv808_cpu.v tb/tb_rv808_cpu.v && vvp tb

# Assemble a program (RV8)
python3 RV8/tools/rv8asm.py RV8/programs/fib.asm -f bin -o fib.bin
```

## Which variant to build?

| Your goal | Build this |
|-----------|-----------|
| Fewest chips, learn basics | **RV801-B** (9 chips, 1 breadboard) |
| Pure gates, no programmer needed | **RV808-G** (20 chips, 2 breadboards) |
| Understand parallel bus architecture | **RV8-G** (23 chips, 3 breadboards) |
| Full-speed, maximum instructions | **RV8** (26 chips, 4 breadboards) |
| Elegant paged design | **RV808** (23 chips, 3 breadboards) |

## The Philosophy

> **RV801** — A CPU can be incredibly simple.
> **RV8-G / RV808-G** — A computer needs no programmable logic.
> **RV8** — How a CPU works.
> **RV808** — How to design one.

## Documentation

| Variant | Docs | Verilog | Tests |
|---------|:----:|:-------:|:-----:|
| RV8 | `RV8/doc/` (12 labs, Thai+English) | ✅ 69/69 pass | ✅ |
| RV808 | `RV808/doc/` (8 labs, Thai+English) | ✅ 44/44 pass | ✅ |
| RV8-G | `RV8G/doc/` (design + control trace) | ✅ 17/17 pass | ✅ |
| RV808-G | `RV808G/doc/` (design) | ⬜ | ⬜ |
| RV801 | `RV801/` (spec + circuit) | ⬜ | ⬜ |

## Status

| Board | Status |
|-------|:------:|
| RV8 CPU (26 chips) | ✅ Designed + simulated |
| RV808 CPU (23 chips) | ✅ Designed + simulated |
| RV8-G CPU (23 chips, gates) | ✅ Designed + simulated |
| RV808-G CPU (20 chips, gates) | 🔧 Design done |
| RV801-B (9 chips) | 🔧 Spec done |
| Programmer board | ✅ Complete (ESP32 + level shifters) |
| Trainer board | 🔧 Design done |
| Full PC board | ⬜ Planned |
| System ROM (BASIC) | ⬜ Planned |
