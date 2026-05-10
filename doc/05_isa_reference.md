# RV8 — Instruction Set Reference (matches working Verilog)

**Status**: Verified — all tests pass  
**Source of truth**: `rv8_cpu.v`

---

## Registers

| Code | Name | Purpose |
|:----:|------|---------|
| 0 | c0 | Constant: 0x00/0x01/0xFF/0x80 (selected by operand[3:2]) |
| 1 | sp | Stack pointer (8-bit, stack at page 0x30) |
| 2 | a0 | Accumulator (ALU destination) |
| 3 | pl | Pointer low byte |
| 4 | ph | Pointer high byte |
| 5 | t0 | Temporary |
| 6 | pg | Page register |

---

## Instructions (implemented and tested)

### ALU Register (0x00–0x07)

`a0 = a0 OP reg[operand]`. Flags: Z, C, N.

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x00 | ADD rs | a0 = a0 + rs |
| 0x01 | SUB rs | a0 = a0 - rs |
| 0x02 | AND rs | a0 = a0 & rs |
| 0x03 | OR rs | a0 = a0 \| rs |
| 0x04 | XOR rs | a0 = a0 ^ rs |
| 0x05 | CMP rs | flags = a0 - rs (no write) |
| 0x06 | ADC rs | a0 = a0 + rs + C |
| 0x07 | SBC rs | a0 = a0 - rs - !C |

### Load Immediate (0x10–0x15)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x10 | LI sp, imm | sp = imm8 |
| 0x11 | LI a0, imm | a0 = imm8 |
| 0x12 | LI pl, imm | pl = imm8 |
| 0x13 | LI ph, imm | ph = imm8 |
| 0x14 | LI t0, imm | t0 = imm8 |
| 0x15 | LI pg, imm | pg = imm8 |

### ALU Immediate (0x16–0x1C)

`a0 = a0 OP imm8`. Flags: Z, C, N.

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x16 | ADDI imm | a0 = a0 + imm8 |
| 0x17 | SUBI imm | a0 = a0 - imm8 |
| 0x18 | CMPI imm | flags = a0 - imm8 (no write) |
| 0x19 | ANDI imm | a0 = a0 & imm8 |
| 0x1A | ORI imm | a0 = a0 \| imm8 |
| 0x1B | XORI imm | a0 = a0 ^ imm8 |
| 0x1C | TST imm | flags = a0 & imm8 (no write) |

### Load/Store (0x20–0x2D)

| Opcode | Mnemonic | Operation | Cycles |
|:------:|----------|-----------|:------:|
| 0x20 | LB a0, (ptr) | a0 = mem[{ph,pl}] | 4 |
| 0x21 | SB a0, (ptr) | mem[{ph,pl}] = a0 | 4 |
| 0x22 | LB a0, (ptr+) | a0 = mem[{ph,pl}]; ptr++ | 4 |
| 0x23 | SB a0, (ptr+) | mem[{ph,pl}] = a0; ptr++ | 4 |
| 0x24 | MOV rd, a0 | rd = a0 | 3 |
| 0x25 | MOV a0, rs | a0 = rs | 3 |
| 0x26 | LB a0, [sp+imm] | a0 = mem[{0x30, sp+imm8}] | 4 |
| 0x27 | SB a0, [sp+imm] | mem[{0x30, sp+imm8}] = a0 | 4 |
| 0x28 | LB a0, [zp+imm] | a0 = mem[{0x00, imm8}] | 4 |
| 0x29 | SB a0, [zp+imm] | mem[{0x00, imm8}] = a0 | 4 |
| 0x2A | LB a0, [pg:imm] | a0 = mem[{pg, imm8}] | 4 |
| 0x2B | SB a0, [pg:imm] | mem[{pg, imm8}] = a0 | 4 |
| 0x2C | PUSH rs | sp--; mem[{0x30,sp}] = rs | 4 |
| 0x2D | POP rd | rd = mem[{0x30,sp}]; sp++ | 4 |

### Branch (0x30–0x36)

PC-relative. Offset = signed 8-bit added to PC (after PC+2 advance).

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

Next instruction executes as NOP if condition true.

| Opcode | Mnemonic | Skip if |
|:------:|----------|---------|
| 0x37 | SKIPZ | Z == 1 |
| 0x38 | SKIPNZ | Z == 0 |
| 0x39 | SKIPC | C == 1 |
| 0x3A | SKIPNC | C == 0 |

### Jump (0x3C–0x3E)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x3C | JMP (ptr) | PC = {ph, pl} |
| 0x3D | JAL (ptr) | push PC; PC = {ph,pl} |
| 0x3E | RET | pop PC |

### Shift/Unary (0x40–0x47)

Operates on a0. Flags: Z (approx), C (for shifts).

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x40 | SHL | a0 = {a0[6:0], 0}; C = old bit7 |
| 0x41 | SHR | a0 = {0, a0[7:1]}; C = old bit0 |
| 0x42 | ROL | a0 = {a0[6:0], C}; C = old bit7 |
| 0x43 | ROR | a0 = {C, a0[7:1]}; C = old bit0 |
| 0x44 | INC | a0 = a0 + 1 |
| 0x45 | DEC | a0 = a0 - 1 |
| 0x46 | NOT | a0 = ~a0 |
| 0x47 | SWAP | a0 = {a0[3:0], a0[7:4]} |

### Pointer (0x48–0x4A)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0x48 | INC16 | {ph,pl} = {ph,pl} + 1 |
| 0x49 | DEC16 | {ph,pl} = {ph,pl} - 1 |
| 0x4A | ADD16 imm | {ph,pl} = {ph,pl} + imm8 |

### System (0xF0–0xFF)

| Opcode | Mnemonic | Operation |
|:------:|----------|-----------|
| 0xF0 | CLC | C = 0 |
| 0xF1 | SEC | C = 1 |
| 0xF2 | EI | IE = 1 (enable interrupts) |
| 0xF3 | DI | IE = 0 (disable interrupts) |
| 0xFE | NOP | No operation |
| 0xFF | HLT | Halt (wake on interrupt if IE=1) |

---

## Memory Map

| Address | Purpose |
|---------|---------|
| 0x0000–0x00FF | Zero page (fast globals via LB/SB [zp+imm]) |
| 0x0100–0x2FFF | RAM (VRAM + workspace) |
| 0x3000–0x30FF | Stack (256 bytes) |
| 0x3100–0x7FFF | Free RAM |
| 0x4000–0x7FFF | Universal bus slot (when card inserted) |
| 0x8000–0x80FF | I/O |
| 0xC000–0xFFFF | ROM (32KB, fixed) |
| 0xFFFC–0xFFFD | Reset vector |

---

## Timing

| Instruction type | Cycles |
|-----------------|:------:|
| ALU reg/imm, LI, shift, MOV, branch(not taken), skip, NOP | 3 |
| LB/SB, PUSH/POP, branch(taken) | 4 |
| SB (write) | 5 |
| JMP | 3 |
| JAL/RET | 5+ |
| Boot (reset vector load) | 3 |

---

## Instruction Count: 52 implemented

| Group | Count |
|-------|:-----:|
| ALU register | 8 |
| Load immediate | 6 |
| ALU immediate | 7 |
| Load/Store | 14 |
| Branch | 7 |
| Skip | 4 |
| Jump | 3 |
| Shift/Unary | 8 |
| Pointer | 3 |
| System | 6 |
| **Total** | **66** |

Undefined opcodes (0x08-0x0F, 0x2E-0x2F, 0x3B, 0x3F, 0x4B-0xEF, 0xF4-0xFD) → treated as NOP.
