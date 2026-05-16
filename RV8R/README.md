# RV8-R — RAM Registers, Full ISA, Microcode

**17 logic chips. Full RISC-V ISA. Registers in RAM. 1.0 MIPS @ 10 MHz.**

| Spec | Value |
|------|-------|
| Logic chips | 17 |
| Total | 20 (+ ROM + RAM + Flash) |
| ISA | Full (35 instructions, same as RV8) |
| Speed | 1.0 MIPS @ 10 MHz |
| Registers | 8 in RAM ($00-$07) |
| Control | 2× Flash microcode |
| Binary compatible | ✅ Same programs as RV8 |
| Pro | **Fewest chips with full ISA** |
| Con | Needs Flash programmer, slightly slower |
