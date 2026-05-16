# RV8-GR — ISA Reference

**21 instructions. RISC-V naming. ~80% compatible with RV8.**

---

## Encoding (2 bytes per instruction)

### Byte 0 — Control (8 bits, drives hardware):
```
Bit 7: ALU_SUB      0=ADD, 1=SUB
Bit 6: XOR_MODE     1=XOR result → AC
Bit 5: MUX_SEL      0=ALU→AC, 1=IBUS→AC
Bit 4: AC_WR        1=write to AC
Bit 3: SOURCE_TYPE  0=immediate, 1=register(RAM)
Bit 2: STORE        1=write AC to RAM
Bit 1: BRANCH       1=conditional jump
Bit 0: JUMP         1=unconditional jump
```

### Byte 1 — Operand (8 bits):
- Immediate value (0-255) when SOURCE_TYPE=0
- Register/memory address when SOURCE_TYPE=1 or STORE=1
- Branch/jump target address when BRANCH=1 or JUMP=1

---

## Instructions

### ALU (AC = AC op source)

| Control byte | Mnemonic | Operation |
|:------------:|----------|-----------|
| $18 | `ADD a0, a0, rs` | AC = AC + RAM[rs] |
| $98 | `SUB a0, a0, rs` | AC = AC - RAM[rs] |
| $48 | `XOR a0, a0, rs` | AC = AC ^ RAM[rs] |
| $10 | `ADDI a0, a0, imm` | AC = AC + imm |
| $90 | `SUBI a0, a0, imm` | AC = AC - imm |
| $50 | `XORI a0, a0, imm` | AC = AC ^ imm |
| $10 | `SLL a0, a0, 1` | AC = AC + AC (shift left, use ADDI with self... actually ADD a0,a0) |

### Load/Move

| Control byte | Mnemonic | Operation |
|:------------:|----------|-----------|
| $30 | `LI a0, imm` | AC = imm (MUX_SEL=1, AC_WR=1) |
| $38 | `MV a0, rs` | AC = RAM[rs] (MUX_SEL=1, SOURCE=1, AC_WR=1) |
| $04 | `MV rd, a0` | RAM[rd] = AC (STORE=1) |
| $3C | `LB a0, addr` | AC = RAM[addr] (MUX_SEL=1, SOURCE=1, AC_WR=1) |
| $04 | `SB a0, addr` | RAM[addr] = AC (STORE=1) |

### Branch/Jump

| Control byte | Mnemonic | Operation |
|:------------:|----------|-----------|
| $02 | `BEQ a0, zero, addr` | if Z=1, PC = addr |
| $82 | `BNE a0, zero, addr` | if Z=0, PC = addr (SUB bit as invert) |
| $01 | `J addr` | PC = addr |
| $11 | `JAL ra, addr` | RAM[$07]=PC, PC = addr (AC_WR saves PC... needs work) |

### System

| Control byte | Mnemonic | Operation |
|:------------:|----------|-----------|
| $00 | `NOP` | nothing |
| $01 | `HLT` | PC = same address (loop) |

---

## What's missing vs RV8:

| RV8 instruction | RV8-GR | Workaround |
|-----------------|:------:|-----------|
| AND/ANDI | ❌ | Subroutine (~20 instr) |
| OR/ORI | ❌ | Subroutine (~25 instr) |
| SRL (shift right) | ❌ | Subroutine (~15 instr) |
| SLT/SLTI | ❌ | SUB + check Z |
| BLT/BGE | ❌ | SUB + BEQ/BNE |
| Relative branch | ❌ | Absolute address (assembler resolves) |
| BEQ rs1,rs2 | ❌ | SUB rs1,rs2 then BEQ |

## Compatibility: ~80% of RV8 programs run if they avoid AND/OR/SRL.
