# RV8 — Minimal 8-bit Educational CPU

Build a real computer from 74HC chips. Learn CPU design, assembly, BASIC, and electronics.

## What is RV8?

RV8 is an 8-bit CPU inspired by the 6502 with RISC-V naming conventions, designed to be built by students on breadboard or PCB.

| Parameter | Value |
|-----------|-------|
| Data bus | 8-bit |
| Address bus | 16-bit (64KB) |
| Instructions | 58 (fixed 2-byte) |
| Registers | 5 (zero, sp, a0, pl, ph) |
| Gate count | ~848 |
| CPU chips | 22 (74HC logic) |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| Video | 320×240, 16 colors + 40×25 text |
| Sound | 8-bit DAC |
| Cost | $64 (trainer) / $120 (full PC) |

## Build Options

- **Trainer** — Hex keypad, LCD, LEDs, single-step debug ($64, 36 chips)
- **Full PC** — QWERTY keyboard, VGA/composite video, BASIC, games ($120, 41 chips)

Both share the same CPU card (26 chips) and universal bus slot for expansion.

## Project Status

- [x] Phase 1: Requirements specification
- [x] Phase 2: ISA design
- [ ] Phase 3: Architecture design
- [ ] Phase 4: Verilog implementation
- [ ] Phase 5: Testbench & verification

## Documentation

- [Summary](00_summary.md) — Full design discussion & decisions
- [Requirements](01_requirements.md) — Hardware specification (v4)
- [ISA Design](02_isa_design.md) — Instruction set architecture (v3)

## License

MIT
