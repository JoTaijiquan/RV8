# RV8 Project — Development History

## Day 1-5 (2026-05-10 to 2026-05-14)
- Original designs explored and archived
- Programmer board complete

## Day 6 (2026-05-15)
- RV8 redesigned (RISC-V, microcode, 27 chips)
- RV8-G and RV8-GR concepts

## Day 7 (2026-05-16-17) — Final Architecture + Implementation

### Designs verified (all traced):
- RV8: 27 chips, microcode, Verilog 8/8 pass
- RV8-R: 18 chips, microcode, RAM registers, traced
- RV8-G: 28 chips, no microcode, full ISA, traced
- RV8-GR: 21 chips, no microcode, reduced ISA, **Verilog 11/11 + assembler + assembly test pass**

### RV8-GR fully implemented:
- Verilog model (11/11 unit tests pass)
- Assembler (rv8gr_asm.py, working)
- Assembly integration test (full pipeline: asm→bin→CPU→pass)
- VCD waveform support (gtkwave)
- Full doc set (design, ISA, trace, wiring, modules, bank switch)

### Bank switch design:
- Run code from RAM via XOR on A15 (fetch path only)
- Registers ($0000-$0007) always safe (data path unchanged)
- Decision: bank switch lives on TRAINER BOARD (not CPU board)
- CPU board stays pure at 21 chips

### Key lessons:
1. Every trace finds 1-2 more chips than claimed
2. Full ISA always costs ~27 chips regardless of approach
3. RAM registers save ~10 chips (proven)
4. "No microcode" doesn't save chips for full ISA (saves for reduced)
5. Bank switch belongs on expansion board, not CPU

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| 2026-05-10 | Project started |
| 2026-05-14 | Programmer board complete |
| 2026-05-15 | RV8 microcode working (8/8) |
| 2026-05-16 | All 4 variants traced and verified |
| 2026-05-17 | **RV8-GR: full toolchain (Verilog + assembler + test) ready for build** |
