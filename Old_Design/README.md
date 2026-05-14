# Old_Design — Archived CPU Designs

These designs require EEPROM for control signal generation. They are complete and verified but superseded by the RV8-G family (pure gates, no EEPROM).

## Contents

| Folder | Chips | Description | Status |
|--------|:-----:|-------------|:------:|
| RV8/ | 26 | Von Neumann, 68 instructions, EEPROM microcode | ✅ 69/69 tests |
| RV801/ | 8-9 | Bit-serial, ultra-minimal | Spec done |
| RV808/ | 23 | Harvard, 67 instructions, page:offset | ✅ 44/44 tests |

## Why archived?

The original designs claimed "hardwired control" but the 68-instruction ISA with 17 states requires a control EEPROM (or ~30+ gate chips) to generate all signals. This contradicts the project goal of **no programmable logic** for the CPU itself.

The RV8-G family solves this by reducing the ISA to ~22-25 instructions where opcode bits wire directly to control points — truly zero programmable logic.

## Still useful for:

- Reference (ISA design decisions, architecture docs)
- KiCad schematics (reusable for RV8-G with modifications)
- Lab sheets (educational content, Thai+English)
- Verilog models (behavioral reference)
- Assembler (rv8asm.py, adaptable for RV8-G)
