# RV8 — Instruction Set Reference

**Source of truth**: `rtl/rv8_cpu.v`  
**Verified**: 69 test assertions pass (all instructions covered)

---

## Registers

| Code | Name | Purpose |
|:----:|------|---------|
| 0 | c0 | Constant generator: bits[4:3] select {0x00, 0x01, 0xFF, 0x80} |
| 1 | sp | Stack pointer (8-bit, stack at page 0x30) |
| 2 | a0 | Accumulator (ALU destination) |
| 3 | pl | Pointer low byte |
| 4 | ph | Pointer high byte |
| 5 | t0 | Temporary |
| 6 | pg | Page register (high byte for page-relative addressing) |

---

## Instruction Format

All instructions are exactly 2 bytes:
```
Byte 0: opcode
Byte 1: operand (register code, immediate value, or branch offset)
```

---

## Instructions (68 total)

### ALU Register (0x00–0x07) — `a0 = a0 OP reg[operand]`

Flags: Z, C, N updated.

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x00 | ADD rs | a0 = a0 + rs |
| 0x01 | SUB rs | a0 = a0 - rs |
| 0x02 | AND rs | a0 = a0 & rs |
| 0x03 | OR rs | a0 = a0 \| rs |
| 0x04 | XOR rs | a0 = a0 ^ rs |
| 0x05 | CMP rs | flags = a0 - rs (a0 unchanged) |
| 0x06 | ADC rs | a0 = a0 + rs + C |
| 0x07 | SBC rs | a0 = a0 - rs - !C |

### Load Immediate (0x10–0x15) — `rd = imm8`

No flags affected.

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x10 | LI sp, imm | sp = imm8 |
| 0x11 | LI a0, imm | a0 = imm8 |
| 0x12 | LI pl, imm | pl = imm8 |
| 0x13 | LI ph, imm | ph = imm8 |
| 0x14 | LI t0, imm | t0 = imm8 |
| 0x15 | LI pg, imm | pg = imm8 |

### ALU Immediate (0x16–0x1C) — `a0 = a0 OP imm8`

Flags: Z, C, N updated.

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x16 | ADDI imm | a0 = a0 + imm8 |
| 0x17 | SUBI imm | a0 = a0 - imm8 |
| 0x18 | CMPI imm | flags = a0 - imm8 (a0 unchanged) |
| 0x19 | ANDI imm | a0 = a0 & imm8 |
| 0x1A | ORI imm | a0 = a0 \| imm8 |
| 0x1B | XORI imm | a0 = a0 ^ imm8 |
| 0x1C | TST imm | flags = a0 & imm8 (a0 unchanged) |

### Load/Store (0x20–0x2D)

No flags affected.

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x20 | LB (ptr) | a0 = mem[{ph,pl}] |
| 0x21 | SB (ptr) | mem[{ph,pl}] = a0 |
| 0x22 | LB (ptr+) | a0 = mem[{ph,pl}]; {ph,pl}++ |
| 0x23 | SB (ptr+) | mem[{ph,pl}] = a0; {ph,pl}++ |
| 0x24 | MOV rd, a0 | reg[operand] = a0 |
| 0x25 | MOV a0, rs | a0 = reg[operand] |
| 0x26 | LB [sp+imm] | a0 = mem[{0x30, sp + imm8}] |
| 0x27 | SB [sp+imm] | mem[{0x30, sp + imm8}] = a0 |
| 0x28 | LB [zp+imm] | a0 = mem[{0x00, imm8}] |
| 0x29 | SB [zp+imm] | mem[{0x00, imm8}] = a0 |
| 0x2A | LB [pg:imm] | a0 = mem[{pg, imm8}] |
| 0x2B | SB [pg:imm] | mem[{pg, imm8}] = a0 |
| 0x2C | PUSH rs | sp--; mem[{0x30, sp}] = reg[operand] |
| 0x2D | POP rd | reg[operand] = mem[{0x30, sp}]; sp++ |

### Branch (0x30–0x36) — PC-relative

Operand = signed 8-bit offset (added to PC after fetch, i.e., relative to instruction after branch).

| Opcode | Mnemonic | Condition |
|:------:|----------|-----------|
| 0x30 | BEQ off | Z == 1 |
| 0x31 | BNE off | Z == 0 |
| 0x32 | BCS off | C == 1 |
| 0x33 | BCC off | C == 0 |
| 0x34 | BMI off | N == 1 |
| 0x35 | BPL off | N == 0 |
| 0x36 | BRA off | Always |

### Conditional Skip (0x37–0x3A)

Next instruction executes as NOP (all side effects suppressed) if condition is true.

| Opcode | Mnemonic | Skip if |
|:------:|----------|---------|
| 0x37 | SKIPZ | Z == 1 |
| 0x38 | SKIPNZ | Z == 0 |
| 0x39 | SKIPC | C == 1 |
| 0x3A | SKIPNC | C == 0 |

### Jump (0x3C–0x3E)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x3C | JMP | PC = {ph, pl} |
| 0x3D | JAL | push PCH, push PCL; PC = {ph, pl} |
| 0x3E | RET | pop PCL, pop PCH |

### Shift/Unary (0x40–0x47) — operates on a0

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x40 | SHL | C = a0[7]; a0 = {a0[6:0], 0} |
| 0x41 | SHR | C = a0[0]; a0 = {0, a0[7:1]} |
| 0x42 | ROL | C = a0[7]; a0 = {a0[6:0], old_C} |
| 0x43 | ROR | C = a0[0]; a0 = {old_C, a0[7:1]} |
| 0x44 | INC | a0 = a0 + 1 |
| 0x45 | DEC | a0 = a0 - 1 |
| 0x46 | NOT | a0 = ~a0 |
| 0x47 | SWAP | a0 = {a0[3:0], a0[7:4]} |

### Pointer Arithmetic (0x48–0x4A)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x48 | INC16 | {ph, pl} = {ph, pl} + 1 |
| 0x49 | DEC16 | {ph, pl} = {ph, pl} - 1 |
| 0x4A | ADD16 imm | {ph, pl} = {ph, pl} + imm8 |

### System (0xF0–0xFF)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0xF0 | CLC | C = 0 |
| 0xF1 | SEC | C = 1 |
| 0xF2 | EI | IE = 1 (enable interrupts) |
| 0xF3 | DI | IE = 0 (disable interrupts) |
| 0xF4 | RTI | Pop flags, pop PCL, pop PCH (return from interrupt) |
| 0xF5 | TRAP imm | Push PCH, PCL, flags; IE=0; PC = mem[0xFFF6:0xFFF7] |
| 0xFE | NOP | No operation |
| 0xFF | HLT | Halt (wakes on NMI or IRQ if IE=1) |

---

## Interrupts

| Source | Trigger | Vector | Maskable |
|--------|---------|--------|:--------:|
| NMI | Falling edge on NMI pin | 0xFFFA | No |
| IRQ | Low level on IRQ pin | 0xFFFE | Yes (IE) |
| TRAP | TRAP instruction | 0xFFF6 | — |
| RESET | Power-on / reset pin | 0xFFFC | — |

Interrupt entry (NMI/IRQ from HLT): reads vector, loads PC. Does NOT auto-push (minimal implementation).  
TRAP: pushes PCH, PCL, flags to stack, then reads vector.  
RTI: pops flags, PCL, PCH from stack.

---

## Memory Map

```
0x0000–0x00FF  Zero page (fast globals via LB/SB [zp+imm])
0x0100–0x2FFF  RAM (VRAM, workspace)
0x3000–0x30FF  Stack (256 bytes, sp indexes here)
0x3100–0x7FFF  Free RAM / universal bus slot window (0x4000–0x7FFF)
0x8000–0x80FF  I/O devices
0xC000–0xFFFF  ROM (32KB, fixed)
0xFFF6–0xFFF7  TRAP vector
0xFFFA–0xFFFB  NMI vector
0xFFFC–0xFFFD  RESET vector
0xFFFE–0xFFFF  IRQ vector
```

---

## Timing (cycles per instruction)

| Type | Cycles |
|------|:------:|
| ALU reg/imm, LI, shift, MOV, skip, NOP | 3 |
| LB/SB, PUSH/POP | 4–5 |
| Branch (not taken) | 3 |
| Branch (taken) | 4 |
| JMP | 3 |
| JAL | 5 |
| RET | 5 |
| RTI | 6 |
| TRAP | 7 |
| HLT→IRQ wake | 3 |

Average: ~3 cycles/instruction → **~1.2M instr/sec @ 3.5 MHz**

---

## Undefined Opcodes

All opcodes not listed above (0x08–0x0F, 0x1D–0x1F, 0x2E–0x2F, 0x3B, 0x3F, 0x4B–0xEF, 0xF6–0xFD) are treated as NOP.
