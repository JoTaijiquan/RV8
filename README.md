# RV8 — Minimal 8-bit Educational CPU

Build a real computer from 74HC chips. 69 tests pass. Complete ISA verified.

## Specs

| Parameter | Value |
|-----------|-------|
| Data/Address | 8-bit data, 16-bit address (64KB) |
| Instructions | 68 (fixed 2-byte), 69 tests pass |
| Registers | 7 (c0, sp, a0, pl, ph, t0, pg) |
| Gates | ~730 |
| Chips | 23 CPU / 27 system |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| Verilog | 240 lines behavioral, 253 lines structural |

## Repository Structure

```
├── README.md
├── rtl/
│   ├── rv8_cpu.v          Behavioral (simulation, all tests pass)
│   └── rv8_synth.v        Structural (FPGA synthesis target)
├── tb/
│   └── tb_rv8_cpu.v       Testbench (69 tests)
├── doc/
│   ├── 00_summary.md      Design decisions & discussion
│   ├── 01_requirements.md Hardware requirements (v5)
│   ├── 02_isa_design.md   ISA design history
│   ├── 03_rv801_spec.md   Ultra-minimal 8-chip variant
│   ├── 04_architecture.md Architecture (verified)
│   └── 05_isa_reference.md ISA reference (source of truth)
```

## Quick Start

```bash
# Simulate
iverilog -g2012 -o rv8_sim rtl/rv8_cpu.v tb/tb_rv8_cpu.v
./rv8_sim

# Expected output: PASS: 69  FAIL: 0
```

## Variants

| Variant | Chips | Speed | Best for |
|---------|:-----:|:-----:|---------|
| RV8 | 23 CPU | 1.2M/s | Full computer, games, BASIC |
| RV801-A | 8 CPU | 175K/s | Learning (needs EEPROM programmer) |
| RV801-B | 9 CPU | 175K/s | Learning (no programmer needed) |

## License

MIT
