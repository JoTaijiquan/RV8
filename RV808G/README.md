# RV808-G — Gates-Only Harvard CPU (Design Study)

**20 chips. Harvard fetch. Page:offset data. Pure gates. No EEPROM.**

## Overview

Harvard variant of RV8-G: ROM wired directly to PC (internal fetch), paged RAM for data. Fewest chips in the family but incompatible with shared-bus ecosystem (Programmer can't flash ROM via bus).

## Specs

| Parameter | Value |
|-----------|-------|
| Chips | 20 (18 logic + ROM + RAM) |
| Registers | 4 (a0, t0, sp, pg) |
| Instructions | ~22 |
| Control | Pure 74HC gates |
| Architecture | Harvard (internal ROM, paged RAM) |
| MIPS | 3.0 @ 10 MHz |

## Status

**Design study only** — not the primary build target.

- ✅ Design document
- ⬜ Verilog model
- ⬜ WiringGuide

## Why not primary?

- ROM is internal → Programmer board can't flash via 40-pin bus
- RAM is internal → Video circuit can't read framebuffer
- Different bus signals → incompatible with Trainer/Computer boards

Kept as an interesting exploration of Harvard + gates-only optimization.
