# RV802 — RISC-V Style 8-bit CPU

**25 logic chips + ROM + RAM = 27 total. 8 registers. Flash microcode. 3.0 MIPS @ 10 MHz.**

## Overview

Register-to-register architecture inspired by RISC-V. Simple hardware (single bus + registers + ALU), complex behavior handled by Flash microcode table.

## Specs

| Parameter | Value |
|-----------|-------|
| Chips | 25 logic + ROM + RAM = 27 total |
| Registers | 8 general-purpose (r0=zero, r7=sp) |
| Instructions | 35 (4 classes) |
| Control | SST39SF010A Flash (70ns, PDIP-32) |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| MIPS | 1.04 @ 3.5 MHz / 3.0 @ 10 MHz |
| Bus | 40-pin (shared with Programmer/Trainer) |

## ISA Summary

| Class | Instructions |
|:-----:|-------------|
| 00 ALU reg | ADD, SUB, AND, OR, XOR, CMP, MOV, SLT, SHL, SHR |
| 01 Immediate | LI, ADDI, SUBI, ANDI, ORI, XORI, CMPI, LUI |
| 10 Memory | LB, SB, LB zp, SB zp, PUSH, POP, LW sp, SW sp |
| 11 Control | BEQ, BNE, BCS, BCC, BRA, JAL, JMP, RET, SYS |

## Status

- ✅ Design document
- ✅ Verilog model (19/21 pass, minor fix pending)
- ✅ WiringGuide (verified buildable, both formats)
- ⬜ Microcode table generator
- ⬜ Assembler
- ⬜ Build guide
