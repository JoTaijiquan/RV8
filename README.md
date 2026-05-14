# RV8-G: Pure Gates 8-bit CPU Family

Build a real computer from 74HC chips. **No EEPROM. No microcode. Pure logic gates.**

## CPU Variants

| | RV8-G | RV808-G |
|--|:---:|:---:|
| **Chips** | 23 | **20** |
| **Architecture** | Von Neumann (shared bus) | Harvard (internal ROM) |
| **Instructions** | 32 | 22 |
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

## ISA (32 instructions)

Format: `[opcode 8-bit] [operand 8-bit]` — all instructions are 2 bytes.

```
opcode[7:6] = class    → 74HC138 decodes into 4 enables
opcode[5:3] = operation → wires directly to ALU/mux/flag select
opcode[1:0] = modifier  → immediate/carry/shift/register select
```

| Class | Instructions | What they do |
|:-----:|-------------|-------------|
| **00** ALU | ADD, SUB, AND, OR, XOR, CMP, INC, DEC | Arithmetic + logic |
| | ADC, SBC, SHL, SHR | Carry chain + shifts |
| | ADDI, SUBI, ANDI, ORI, XORI, CMPI | Immediate variants |
| | MOV t0,a0 | Register move |
| **01** Load/Store | LI a0/t0/sp/pl/ph | Load immediate |
| | LB/SB (ptr), LB (ptr+), LB/SB zp:imm | Memory access |
| | MOV pl,a0 / MOV ph,a0 | Computed pointer |
| **10** Branch | BEQ, BNE, BCS, BCC, BMI, BPL, BRA | Conditional branch |
| | JMP imm, JMP (ptr) | Absolute + computed jump |
| **11** System | PUSH, POP, CALL, RET | Stack + subroutines |
| | NOP, HLT, EI, DI | Control |

**Enough for**: BASIC interpreter, video games, sound, 16-bit math.

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
| RV8-G Verilog (24/24 pass) | ✅ |
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
