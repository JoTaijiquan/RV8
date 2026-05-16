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

---

## Chip List (27 logic)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U8 | 74HC574 ×8 | Registers r0-r7 |
| U9-U10 | 74HC574 ×2 | IR (opcode + operand) |
| U11 | 74HC574 | ALU B latch |
| U12-U13 | 74HC283 ×2 | ALU adder (8-bit) |
| U14-U15 | 74HC86 ×2 | XOR (SUB invert) |
| U16-U17 | 74HC574 ×2 | PC (low + high, /OE) |
| U18-U19 | 74HC574 ×2 | Address latches (low + high) |
| U20 | 74HC138 | Register read select |
| U21 | 74HC138 | Register write select |
| U22 | 74HC245 | Bus buffer (IBUS ↔ RAM) |
| U23 | SST39SF010A | Microcode Flash #1 |
| U24 | 74HC74 | Flags (Z, C) |
| U25 | 74HC574 | ALU result latch |
| U26 | 74HC161 | Step counter |
| U27 | SST39SF010A | Microcode Flash #2 |
| — | AT28C256 | Program ROM |
| — | 62256 | RAM |
