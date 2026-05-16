# RV8-W — No Microcode, RAM Registers

Two sub-variants: **RV8-WF** (full ISA) and **RV8-WR** (reduced ISA).

## RV8-WF (Full ISA, No Microcode)

| Spec | Value |
|------|-------|
| Logic chips | 27 |
| Total | 29 |
| ISA | Full (35 instructions, same as RV8) |
| Speed | 1.7 MIPS @ 10 MHz |
| Registers | 8 in RAM |
| Control | **None** — instruction bits drive hardware directly |
| Binary compatible | ✅ Same programs as RV8 |
| Pro | **No microcode + full ISA + fastest** |
| Con | Same chip count as RV8, more complex wiring |

## RV8-WR (Reduced ISA, No Microcode)

| Spec | Value |
|------|-------|
| Logic chips | 19 |
| Total | 21 |
| ISA | Reduced (20 instructions, no AND/OR/XOR, no relative branch) |
| Speed | 1.7 MIPS @ 10 MHz |
| Registers | 8 in RAM |
| Control | **None** — instruction bits drive hardware directly |
| Pro | **Fewest chips that plays games, no microcode** |
| Con | Missing logic ops + relative branch |

## Files

```
RV8W/
├── README.md
└── doc/
    ├── 00_design.md
    ├── 01_understand_by_module.md
    ├── 02_v2_ram_registers.md
    └── WiringGuide.md
```
