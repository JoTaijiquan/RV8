# RV8 Project — Session Memory

**Last updated**: 2026-05-16 16:55

---

## Active Designs

| Variant | Chips | Control | MIPS@10MHz | Status |
|---------|:-----:|---------|:----------:|:------:|
| **RV8** | 25 logic (+ROM+RAM=27) | Flash microcode | 2.17 | ✅ Verilog + WiringGuide verified |
| **RV8-G** | 26 logic (+ROM+RAM=28) | Pure gates | 2.5 | ✅ Verilog 34/34, WiringGuide has issues |

## Key Realization (Day 7):

**Three approaches to CPU control, all valid:**

```
1. Pure gates:     29+ chips, limited ISA — hard to route all signals
2. Microcode ROM:  25 chips, rich ISA — one Flash chip does all decode (RV8)
3. Wide ROM:       17 chips, rich ISA — 16-bit instruction = control bits (Gigatron style)
```

The fundamental problem: 8-bit opcode needs ~16 control wires. Translation costs chips (gates) or a lookup ROM (microcode). Wide ROM avoids translation entirely.

## RV8-G Issues Found (Day 7):

- AND/OR/XOR impossible with adder-only ALU
- No path for LI/LB data to bypass ALU to registers
- No path for a0 → data bus (store operations)
- Fixing these adds 3+ chips → 29+ total
- Pure gates approach costs MORE chips than microcode approach

## RV8 Status:

- WiringGuide verified: no bus conflicts, 10MHz timing OK
- Address conflict fixed: PC as 74HC574 (has /OE) + address latches
- Understand_by_Module.md created (6 modules, student-friendly)
- Verilog: 19/21 pass (2 minor issues)

## Design Philosophy Conclusion:

> **RV8 (microcode) = fewer chips + more capable + verified buildable**
> **RV8-G (pure gates) = more chips + less capable + routing problems**
> **Wide ROM (Gigatron) = fewest chips + fastest + 2× code size**

## Folder Structure

```
/home/jo/kiro/RV8/
├── RV8/          ← 25-chip RISC-V style, Flash microcode (PRIMARY)
├── RV8G/           ← 26-chip pure gates (SECONDARY, has issues)
├── RV808G/         ← 20-chip Harvard (design study)
├── Programmer/     ← ESP32 board (works with all)
├── Old_Design/     ← Archived (RV8 original, RV801, RV808)
├── .kiro/agents/   ← 5 agents
└── README.md
```

## Next Steps

- [ ] Decide: RV8 (microcode) vs Wide ROM (Gigatron style) vs fix RV8-G
- [ ] Whichever chosen: complete WiringGuide, assembler, build
- [ ] Programmer board physical build
- [ ] BASIC interpreter
- [ ] Video circuit (Apple II style, shared RAM)

## Reference: Gigatron TTL Computer (proven design)

- 34 TTL chips, NO microprocessor, runs games + VGA video + sound
- Harvard architecture, 16-bit wide ROM (instruction = control bits)
- 6 chips decode 8 instruction bits → 19 control signals (no EEPROM!)
  - 74HC138 ×2 + 74HC153 + 74HC139 + 74HC240 + 74HC32
- CPU bit-bangs VGA directly (software replaces video chip)
- vCPU: interpreted virtual CPU in software (34 instructions, runs from RAM)
- This is the "wide ROM" approach that solves RV8-G's decode problem
