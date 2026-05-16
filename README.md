# RV8 Project: Minimal 8-bit RISC-V Style CPU Family

Build real computers from 74HC chips on breadboards.

## Active Designs

| | RV8 | RV8-W | RV8-G |
|--|:---:|:---:|:---:|
| **Logic chips** | 27 | **24** | 26 |
| **Total** | 29 | **26** | 28 |
| **Gates** | ~765 | **~640** | ~820 |
| **MIPS @ 10 MHz** | 2.17 | **5.0** | 2.5 |
| **Control** | Flash microcode | **No microcode** | Pure gates |
| **ISA style** | RISC-V reg-reg | **RISC-V accumulator** | Accumulator |
| **Cycles/instr** | 4-6 | **2** | 4 |
| **ROM** | SST39SF010A | SST39SF010A | AT28C256 |
| **Best for** | Flexibility | **Speed + simplicity** | No-programmer purists |

## Project Structure

```
RV8/
├── RV8/            ← RV8 (27 chips, RISC-V reg-reg, Flash microcode)
├── RV8W/           ← RV8-W (24 chips, RISC-V accumulator, no microcode)
├── RV8G/           ← RV8-G (26 chips, pure gates, no programmable logic)
├── Programmer/     ← ESP32 board (flash ROM + terminal)
├── Old_Design/     ← Archived designs
├── Reference/      ← Gigatron, SAP-1, Nand2Tetris
└── README.md
```

## Quick Start

```bash
# Simulate RV8
cd RV8 && iverilog -o tb rv8_cpu.v tb/tb_rv8_cpu.v && vvp tb

# Simulate RV8-G
cd RV8G && iverilog -o tb rv8g_cpu.v tb/tb_rv8g_cpu.v && vvp tb
```

## The Philosophy

> **RV8**: Full RISC-V register-register. Most flexible. Needs microcode Flash.
> **RV8-W**: Fastest, fewest chips. Accumulator with RISC-V naming. No microcode.
> **RV8-G**: Pure gates, no programmable logic at all. Educational.

All three run BASIC and video games. All use the same 40-pin bus and Programmer board.
