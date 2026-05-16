# RV8-S — Serial ALU, RAM Registers, Microcode

**15 logic chips. Full RISC-V ISA. 1-bit serial ALU. 0.3 MIPS @ 10 MHz.**

| Spec | Value |
|------|-------|
| Logic chips | 15 |
| Total | 18 (+ ROM + RAM + Flash) |
| ISA | Full (35 instructions, same as RV8) |
| Speed | 0.3 MIPS @ 10 MHz |
| Registers | 8 in RAM, 2× shift register for ALU |
| ALU | 1-bit serial (XOR + AND + carry FF) |
| Control | 1× Flash + 1× 74HC138 |
| Binary compatible | ✅ Same programs as RV8 |
| Pro | **Absolute minimum chip count** |
| Con | Too slow for games, BASIC barely works |
