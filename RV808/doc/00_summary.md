# RV808 — Project Summary

**Minimal 8-bit CPU — Harvard architecture, page:offset data access**

## What Is RV808?

A minimal 8-bit CPU built from 23 chips on 3 breadboards. Harvard variant of RV8 — internal ROM fetch, 8-bit paged data bus. Designed for elegance: everything is 8-bit.

## Specs

| Parameter | Value |
|-----------|-------|
| Data bus | 8-bit |
| Code space | 32KB (ROM, internal fetch) |
| Data space | 32KB RAM (paged: 128 pages × 256 bytes) |
| Instructions | 60 (fixed 2-byte, direct-encoded) |
| Registers | 4: a0, t0, sp, pg (+constant generator) |
| Flags | Z, C, N + IE |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| CPU chips | 21 (74HC series) |
| Board total | 23 chips (21 CPU + ROM + RAM) |
| Control | Hardwired FSM, no microcode |
| Power | 5V USB, <1W |
| Avg cycles/instr | ~3.5 |
| MIPS | 1.0 (bread) / 2.86 (PCB) |

## Architecture

```
┌──────────────────────────────────────────────────┐
│  RV808 CPU BOARD (23 chips, self-contained)       │
│  PC → ROM (internal) │ pg:offset → RAM (paged)   │
└────────────────────────┬─────────────────────────┘
                         │ 40-pin I/O bus
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Programmer  │ │   Trainer    │ │  Video/IO    │
│  ROM flash   │ │  Step/LEDs   │ │  HDMI, SD    │
│  UART term   │ │  Keyboard    │ │  Sound       │
└──────────────┘ └──────────────┘ └──────────────┘
```

## Documents

| # | File | Content |
|---|------|---------|
| 00 | design_notes.md | Exploration and design decisions |
| 01 | harvard_deep.md | Deep design (memory model, ISA, state machine) |
| 02 | architecture.md | Full architecture (encoding, datapath, timing) |
| 03 | circuit.md | 23 chips, pin-level connections |
| 04 | build_guide.md | 8-lab build guide |
| 05 | changelog.md | Version history |
| 06 | history.md | Development timeline |

## Key Files

```
rv808_cpu.v            — Verilog behavioral model (40 tests pass)
tb/tb_rv808_cpu.v      — Testbench
doc/                   — All documentation
```

## Status

- ✅ Architecture design (23 chips, 60 instructions)
- ✅ Verilog model (40/40 tests pass)
- ✅ Circuit diagram (pin-level)
- ✅ Build guide (8 labs)
- ⬜ Assembler (rv808asm.py)
- ⬜ Breadboard build
- ⬜ PCB layout

## RV8 vs RV808

| | RV8 | RV808 |
|--|:---:|:---:|
| Chips | 26 | **23** |
| Bus pins | 40 (all active) | 40 (20 active, 8 reserved) |
| MIPS @ 10 MHz | 4.0 | 2.86 |
| BASIC + games | ✅ | ✅ |
| Education focus | How a CPU works | How to design one |
| Elegance | Good | **Beautiful** |

> RV8 teaches you how a CPU works. RV808 teaches you how to design one.
