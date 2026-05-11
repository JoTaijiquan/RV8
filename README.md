# RV8: Minimal 8-bit CPU — Accumulator-based, RISC-inspired

Build a real computer from 74HC chips on breadboards.

## Specs

| Parameter | Value |
|-----------|-------|
| Data width | 8-bit |
| Address space | 16-bit (64KB) |
| Instructions | 68 (fixed 2-byte), 69 tests pass |
| Registers | 7 (c0, sp, a0, pl, ph, t0, pg) |
| ALU | ADD, SUB, AND, OR, XOR, SHL, SHR, ADC, SBC |
| Gates | ~730 |
| CPU chips | 23 (74HC series) |
| System total | 27 chips |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| Encoding | Direct-decoded opcode bits, no microcode |

## Instruction Format

All instructions are exactly 2 bytes:
```
Byte 0: opcode    [unit:3][op:3][reg:2]
Byte 1: operand   (register, immediate, or branch offset)
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  RV8 CPU                        │
│                                                 │
│  ┌────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌──────┐ │
│  │ PC │  │ IR  │  │Regs │  │ ALU │  │ Ctrl │ │
│  │16b │  │op+im│  │7×8b │  │ 8b  │  │ FSM  │ │
│  └────┘  └─────┘  └─────┘  └─────┘  └──────┘ │
│  ┌──────┐  ┌──────┐                            │
│  │ PTR  │  │Flags │                            │
│  │16b   │  │Z,C,N │                            │
│  └──────┘  └──────┘                            │
│                                                 │
│  40-pin expansion connector                     │
└─────────────────────────────────────────────────┘
```

## Repository Structure

```
rv8_cpu.v           Main CPU implementation (Verilog)
doc/                Design documents
  00_summary.md       Project overview
  01_requirements.md  Requirements spec
  02_isa_design.md    ISA design rationale
  04_architecture.md  Microarchitecture
  05_isa_reference.md Instruction set reference (source of truth)
  06_circuit.md       Circuit diagram (27 chips, pin-by-pin)
rtl/                Reference RTL
  rv8_cpu.v           Behavioral Verilog
  rv8_synth.v         Synthesizable/structural version
tb/                 Testbench
  tb_rv8_cpu.v        69-test verification suite
tools/              Development tools
  rv8asm.py           Cross-assembler (Python, Intel HEX output)
programs/           Example programs
  fib.asm             Fibonacci sequence demo
  fib_tb.v            Fibonacci testbench
programmer/         ROM programming tools
  bootloader.asm      Serial bootloader ($FE00-$FFFF)
  rv8upload.py        Upload via Pico (PROG mode)
  rv8upload_serial.py Upload via serial (bootloader mode)
trainer/            Trainer/peripheral board
  README.md           Circuit design (ESP32 + 8 chips)
  rv8_trainer_esp32.ino  ESP32 firmware
rv801/              Simplified variants (8-11 chips)
  03_rv801_spec.md    RV801 spec
  07_rv801_circuit.md RV801 circuit diagrams
reference/          Old/study designs
  riscv_cpu.v         32-bit RISC-V (reference)
  cpu6502.v           6502 (reference)
```

## Hardware

| Board | Chips | Cost |
|-------|:-----:|:----:|
| CPU board | 27 | ~$21 |
| Trainer board | 8 + ESP32 | ~$23 |
| **Total** | **35 + ESP32** | **~$44** |

## Quick Start

```bash
# Assemble a program
python3 tools/rv8asm.py programs/fib.asm -f bin -o fib.bin

# Simulate (with Icarus Verilog)
iverilog -o sim rtl/rv8_cpu.v tb/tb_rv8_cpu.v
vvp sim

# Upload to hardware (via trainer board serial)
python3 programmer/rv8upload_serial.py /dev/ttyUSB0 fib.bin
```

## Variants

| Variant | Chips | Speed | Notes |
|---------|:-----:|:-----:|-------|
| RV8 (full) | 27 | 3.5 MHz | Parallel ALU, 2-cycle base |
| RV801-A | 11 | 175K/s | Bit-serial, EEPROM microcode |
| RV801-B | 12 | 175K/s | Bit-serial, hardwired (no programmer needed) |

All variants run the same programs from the same ROM.
