# RV8 Project — Development History

## Day 1-5 (2026-05-10 to 2026-05-14)
- Original designs explored and archived

## Day 6 (2026-05-15)
- RV8 redesigned (RISC-V, microcode)
- RV8-G designed then archived (pure gates, broken)

## Day 7 (2026-05-16) — Final Architecture

### Key discoveries:
1. Full ISA always costs ~27 chips (regardless of approach)
2. RAM registers save ~10 chips (proven by RV801-A pattern)
3. Serial ALU doesn't save enough to justify speed loss (RV8-S archived)
4. "No microcode" with full ISA = same chip count as microcode (RV8-W = 27)
5. Reduced ISA (drop AND/OR/XOR + relative branch) = real savings (RV8-WR = 19)

### Final family:
| Variant | Chips | ISA | Microcode | Speed |
|---------|:-----:|:---:|:---------:|:-----:|
| RV8-R | **17** | Full | Yes | 1.0 MIPS |
| RV8-WR | **19** | Reduced | No | 1.7 MIPS |
| RV8 | 27 | Full | Yes | 1.25 MIPS |
| RV8-W | 27 | Full | No | 1.7 MIPS |

### Archived (not worth building):
- RV8-G: pure gates, 32 chips honest, broken routing
- RV8-S: serial ALU, 15 chips but 0.3 MIPS, too slow
- RV808/RV801/original RV8: superseded

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| 2026-05-10 | Project started |
| 2026-05-14 | Programmer board complete |
| 2026-05-15 | RV8 microcode working (8/8 tests) |
| 2026-05-16 | **Final family defined: RV8/RV8-R/RV8-W/RV8-WR** |
