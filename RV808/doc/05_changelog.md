# RV808 Changelog

## v0.1 — 2026-05-13
- Initial design: Harvard architecture, 23 chips, page:offset data bus
- Defined ISA: 60 instructions, 2-byte fixed format, 8 units
- Registers: a0, t0, sp, pg (4 registers + constant generator)
- Memory model: 32KB ROM (internal fetch) + 32KB RAM (paged data)
- Code overlay: run from RAM at $4000-$7FFF via RAM_EXEC bit
- ROM banking: 64KB+ via spare flip-flop bits (0 extra chips)
- State machine: 10 states, avg 3.5 cycles/instruction
- Verilog model: rv808_cpu.v (behavioral)
- Testbench: 40/40 tests pass (ALU, LI, LB/SB, branches, PUSH/POP, JAL/RET, TRAP/RTI, NMI, IRQ)
- Circuit diagram: pin-level, 23 chips, 3 breadboards
- Build guide: 8 labs
- 40-pin expansion bus with 4 pre-decoded slots
- Performance: 1.0 MIPS @ 3.5 MHz, 2.86 MIPS @ 10 MHz
