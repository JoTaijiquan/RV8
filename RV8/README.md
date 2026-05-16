# RV8 — Full ISA, Hardware Registers, Microcode

**27 logic chips. Full RISC-V ISA. 8 hardware registers. Flash microcode. 1.25 MIPS.**

| Spec | Value |
|------|-------|
| Logic chips | 27 |
| Total | 29 |
| ISA | Full (35 instructions) |
| Speed | 1.25 MIPS @ 10 MHz |
| Registers | 8 hardware (74HC574) |
| Control | 2× Flash microcode |
| Pro | **Most proven, easiest to modify (change microcode = change behavior)** |
| Con | Most chips, needs Flash programmer, slowest of the family |

## Files

```
RV8/
├── README.md
├── rv8_cpu.v              ← behavioral Verilog
├── rv8_cpu_ucode.v        ← microcode-driven Verilog (8/8 pass)
├── microcode.hex          ← generated microcode table
├── tb/                    ← testbenches
├── tools/microcode_gen.py ← microcode generator
└── doc/
    ├── 00_design.md
    ├── 01_isa_reference.md
    ├── 02_instruction_trace.md
    ├── 03_rv8w_exploration.md
    ├── 04_microcode_format.md
    ├── 05_understand_by_module.md
    └── 06_wiring_guide.md
```
