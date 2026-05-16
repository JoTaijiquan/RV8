# RV8 Project — Development History

---

## Day 1-5 (2026-05-10 to 2026-05-14)
- Original designs (RV8, RV808, RV801) — all archived
- Programmer board complete

## Day 6 (2026-05-15)
- RV8 redesigned (RISC-V reg-reg, microcode)
- RV8-G designed then archived (pure gates, broken hardware)

## Day 7 (2026-05-16) — Verification & Final Designs

### RV8 verified and fixed:
- Instruction trace found 2 missing chips (step counter + 2nd Flash)
- WiringGuide fixed: 27 logic chips (honest)
- 16-bit control output via 2× Flash

### RV8-W designed and verified:
- Accumulator + 2-cycle fetch from 8-bit Flash
- WiringGuide found: 25 chips (not 24 — AC buffer needed)
- AND/OR/XOR impossible with adder-only ALU (same as RV8-G)
- 2.5 MIPS @ 5 MHz (Flash timing limits clock)

### RV8-S designed:
- Serial ALU (1-bit), 74HC595 shift registers
- 20 logic chips, same ISA as RV8
- 1.0 MIPS @ 10 MHz

### Final family:
| Variant | Chips | MIPS | Logic ops | Best for |
|---------|:-----:|:----:|:---------:|----------|
| RV8-S | 20 | 1.0 | ✅ | Fewest chips |
| RV8-W | 25 | 2.5 | ❌ | Speed (no microcode) |
| RV8 | 27 | 2.17 | ✅ | Full ISA + flexibility |

### Key lesson:
AND/OR/XOR requires either microcode (to sequence ALU differently)
or dedicated logic chips. Adder-only designs can't do logic ops.
Only RV8 and RV8-S (with microcode) support full logic operations.

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| 2026-05-10 | Project started |
| 2026-05-14 | Programmer board complete |
| 2026-05-15 | RV8 + RV8-G designed |
| 2026-05-16 | **RV8/RV8-W/RV8-S verified, WiringGuides complete** |
