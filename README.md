# RV8: Minimal 8-bit CPU Family

Build real computers from 74HC chips on breadboards.

## CPU Variants

| | RV801-A | RV801-B | RV8 | RV808 |
|--|:---:|:---:|:---:|:---:|
| **Architecture** | Bit-serial | Bit-serial | Parallel | Harvard |
| **Chips** | **8** | **9** | 26 | 23 |
| **System total** | 11 | 12 | 26 | 23 |
| **ALU** | 1-bit serial | 1-bit serial | 8-bit parallel | 8-bit parallel |
| **Registers** | In RAM | In RAM | Hardware (574) | Hardware (574) |
| **Control** | EEPROM microcode | Hardwired | Hardwired | Hardwired |
| **Speed** | ~175K instr/s | ~175K instr/s | ~1.4M instr/s | ~1.0M instr/s |
| **MIPS @ 10 MHz** | — | — | 4.0 | 2.86 |
| **Bus** | 16-bit parallel | 16-bit parallel | 16-bit parallel | 8-bit paged |
| **Bus pins** | 40 | 40 | 40 | 40 (20 active) |
| **Breadboards** | 1 | 1 | 4 | 3 |
| **Cost** | ~$15 | ~$13 | ~$18 | ~$14 |
| **Build time** | 1-2 weeks | 1-2 weeks | 4-5 weeks | 3-4 weeks |
| **ISA** | RV8 (68 instr) | RV8 (68 instr) | RV8 (68 instr) | RV808 (60 instr) |
| **Software compat** | 100% RV8 | 100% RV8 | — | ~85% RV8 |
| **Run BASIC** | ⚠️ Slow | ⚠️ Slow | ✅ | ✅ |
| **Play games** | Simple only | Simple only | ✅ | ✅ |
| **Best for** | Ultra-minimal | No programmer | Full computer | Elegant design |

## Project Structure

```
RV8/
├── RV8/            ← RV8 CPU (26 chips, parallel) — DONE
├── RV808/          ← RV808 CPU (23 chips, Harvard) — DONE
├── Trainer/        ← Trainer board (SBC style) — planned
├── Computer/       ← Full PC board — planned
├── Rom/            ← System ROM (BASIC + monitor) — planned
├── Reference/      ← Study designs (6502, RISC-V)
└── README.md
```

Note: RV801-A/B specs are in `RV8/rv801/`.

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
| Fewest chips possible, learn basics | **RV801-B** (9 chips, 1 breadboard) |
| Understand parallel CPU architecture | **RV8** (26 chips, 4 breadboards) |
| Elegant minimal design, run BASIC | **RV808** (23 chips, 3 breadboards) |
| Full-speed computer with games | **RV8** on PCB @ 10 MHz |

## The Philosophy

> **RV801** teaches you that a CPU can be incredibly simple.
> **RV8** teaches you how a CPU works.
> **RV808** teaches you how to design one.

## Documentation

| Variant | Docs | Verilog | Tests |
|---------|:----:|:-------:|:-----:|
| RV8 | `RV8/doc/` (12 labs, Thai+English) | ✅ 69/69 pass | ✅ |
| RV808 | `RV808/doc/` (8 labs, Thai+English) | ✅ 40/40 pass | ✅ |
| RV801 | `RV8/rv801/` (spec + circuit) | ⬜ | ⬜ |

## Status

| Board | Status |
|-------|:------:|
| RV8 CPU (26 chips) | ✅ Designed + simulated |
| RV808 CPU (23 chips) | ✅ Designed + simulated |
| RV801-A (8 chips) | 🔧 Spec done |
| RV801-B (9 chips) | 🔧 Spec done |
| Programmer board | 🔧 Design done |
| Trainer board | 🔧 Design done |
| Full PC board | ⬜ Planned |
| System ROM (BASIC) | ⬜ Planned |
