# RV8 Project: Minimal 8-bit CPU Family

Build real computers from 74HC chips on breadboards.

## Active Designs

| | RV802 | RV8-G |
|--|:---:|:---:|
| **Logic chips** | **25** | 27 |
| **Total (+ ROM + RAM)** | **27** | 29 |
| **Registers** | 8 (RISC-V style) | 5 (accumulator) |
| **ISA** | 35 instr (register-register) | 30 instr (accumulator) |
| **Control** | Flash microcode (SST39SF010A) | Pure gates (no EEPROM) |
| **MIPS @ 10 MHz** | **3.0** | 2.5 |
| **Needs programmer** | Yes (Flash) | **No** |
| **Verified buildable** | ✅ | ✅ |
| **Best for** | Performance + clean ISA | No-programmer purists |

## Project Structure

```
RV8/
├── RV802/          ← 23 chips, RISC-V style, Flash microcode — ACTIVE
├── RV8G/           ← 27 chips, accumulator, pure gates — ACTIVE
├── RV808G/         ← 20 chips, Harvard, gates (design study)
├── Programmer/     ← ESP32 board (flash ROM + terminal)
├── Old_Design/     ← Archived (RV8 original, RV801, RV808)
├── Trainer/        ← Trainer board (planned)
├── Computer/       ← Full PC board (planned)
└── README.md
```

## Quick Start

```bash
# Simulate RV8-G (working now)
cd RV8G && iverilog -o tb rv8g_cpu.v tb/tb_rv8g_cpu.v && vvp tb

# Flash a program (with Programmer board)
python3 Programmer/tools/rv8flash.py /dev/ttyUSB0 program.bin
```

## Which to build?

| Your goal | Build |
|-----------|-------|
| Fewest chips, fastest, RISC-V style | **RV802** (23 chips) |
| No programmer needed, pure gates | **RV8-G** (27 chips) |

## The Philosophy

> **RV802**: Simple hardware + smart microcode = powerful CPU.
> **RV8-G**: No black boxes — every signal is a wire you placed.

## Status

| Item | RV802 | RV8-G |
|------|:-----:|:-----:|
| Design doc | ✅ | ✅ |
| Verilog model | ✅ (19/21) | ✅ (34/34) |
| WiringGuide (verified) | ✅ | ⬜ (needs rewrite) |
| Assembler | ⬜ | ⬜ |
| Build guide | ⬜ | ⬜ |
| Programmer board | ✅ | ✅ |
