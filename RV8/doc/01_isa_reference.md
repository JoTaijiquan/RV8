# RV8 — ISA Reference (RISC-V Look and Feel)

**8-bit RISC-V inspired. Same syntax, same patterns, 8-bit scale.**

---

## Registers

| Register | ABI Name | Purpose |
|:--------:|:--------:|---------|
| r0 | zero | Hardwired zero (writes ignored) |
| r1 | ra | Return address |
| r2 | a0 | Argument / return value |
| r3 | a1 | Argument |
| r4 | t0 | Temporary |
| r5 | t1 | Temporary |
| r6 | s0 | Saved / page register |
| r7 | sp | Stack pointer |

---

## Instruction Format (16-bit = 2 bytes)

```
Byte 1: [class(2)][op(3)][rd/rs1(3)]
Byte 2: [rs2(3)][imm5(5)]  OR  [imm8(8)]
```

---

## Class 00: ALU Register-Register

**Format**: `OP rd, rd, rs` (rd = rd OP rs)

| Op[5:3] | Mnemonic | Operation | RISC-V equivalent |
|:-------:|----------|-----------|:-----------------:|
| 000 | ADD rd, rd, rs | rd ← rd + rs | ADD |
| 001 | SUB rd, rd, rs | rd ← rd - rs | SUB |
| 010 | AND rd, rd, rs | rd ← rd & rs | AND |
| 011 | OR rd, rd, rs | rd ← rd \| rs | OR |
| 100 | XOR rd, rd, rs | rd ← rd ^ rs | XOR |
| 101 | SLT rd, rd, rs | rd ← (rd < rs) ? 1 : 0 | SLT |
| 110 | SLL rd | rd ← rd << 1 | SLL (shift=1) |
| 111 | SRL rd | rd ← rd >> 1 | SRL (shift=1) |

**Encoding**: `[00][op3][rd3] [rs3][00000]`

---

## Class 01: ALU Immediate

**Format**: `OP rd, imm8`

| Op[5:3] | Mnemonic | Operation | RISC-V equivalent |
|:-------:|----------|-----------|:-----------------:|
| 000 | LI rd, imm | rd ← imm (= ADDI rd, zero, imm) | LI (pseudo) |
| 001 | ADDI rd, imm | rd ← rd + imm | ADDI |
| 010 | SUBI rd, imm | rd ← rd - imm | (ADDI negative) |
| 011 | ANDI rd, imm | rd ← rd & imm | ANDI |
| 100 | ORI rd, imm | rd ← rd \| imm | ORI |
| 101 | XORI rd, imm | rd ← rd ^ imm | XORI |
| 110 | SLTI rd, imm | rd ← (rd < imm) ? 1 : 0 | SLTI |
| 111 | LUI rd, imm | rd ← imm << 4 | LUI (scaled) |

**Encoding**: `[01][op3][rd3] [imm8]`

---

## Class 10: Load/Store

**Format**: `LB/SB rd, offset(rs)` — RISC-V style!

| Op[5:3] | Mnemonic | Operation | RISC-V equivalent |
|:-------:|----------|-----------|:-----------------:|
| 000 | LB rd, off(rs) | rd ← mem[rs + sext(off5)] | LB |
| 001 | SB rd, off(rs) | mem[rs + sext(off5)] ← rd | SB |
| 010 | LB rd, addr | rd ← mem[{0, imm8}] | LB (zero-page) |
| 011 | SB rd, addr | mem[{0, imm8}] ← rd | SB (zero-page) |
| 100 | PUSH rd | sp--, mem[sp] ← rd | (pseudo: ADDI sp,-1; SB) |
| 101 | POP rd | rd ← mem[sp], sp++ | (pseudo: LB; ADDI sp,1) |
| 110 | LB rd, off(sp) | rd ← mem[sp + off] | LB (stack frame) |
| 111 | SB rd, off(sp) | mem[sp + off] ← rd | SB (stack frame) |

**Encoding**: `[10][op3][rd3] [rs3][off5]` or `[10][op3][rd3] [imm8]`

---

## Class 11: Branch/Jump (RISC-V style — compare two registers)

**Format**: `Bxx rs1, rs2, offset` — branch compares rs1 and rs2 directly!

| Op[5:3] | Mnemonic | Condition | RISC-V equivalent |
|:-------:|----------|-----------|:-----------------:|
| 000 | BEQ rs1, rs2, off | branch if rs1 == rs2 | BEQ |
| 001 | BNE rs1, rs2, off | branch if rs1 ≠ rs2 | BNE |
| 010 | BLT rs1, rs2, off | branch if rs1 < rs2 (unsigned) | BLTU |
| 011 | BGE rs1, rs2, off | branch if rs1 ≥ rs2 (unsigned) | BGEU |
| 100 | JAL rd, off8 | rd ← PC+2, PC ← PC + sext(off8) | JAL |
| 101 | JALR rd, rs | rd ← PC+2, PC ← rs | JALR |
| 110 | J off8 | PC ← PC + sext(off8) (= JAL zero) | J (pseudo) |
| 111 | SYS imm | NOP/HLT/ECALL/EBREAK | ECALL |

**Encoding**: `[11][op3][rs1_3] [rs2_3][off5]` or `[11][op3][rd3] [off8]`

### How BEQ works internally (microcode, no extra chips):
```
Step 0: fetch opcode → get rs1
Step 1: fetch operand → get rs2 + offset
Step 2: rs1 → bus → ALU A latch
Step 3: rs2 → ALU B, subtract, check if zero
Step 4: if zero → PC += offset, else continue
```

No flags register visible to programmer. Compare happens inside the branch.
(Hardware still uses a 1-bit latch internally — but ISA hides it.)

---

## Assembly Examples (looks like RISC-V!)

```asm
# Fibonacci
    LI   r2, 0          # a = 0
    LI   r3, 1          # b = 1
    LI   r4, 10         # count = 10
loop:
    ADD  r5, r2, r3     # temp = a + b  (actually: MOV r5,r2; ADD r5,r5,r3)
    ADD  r2, r3, zero   # a = b (MOV)
    ADD  r3, r5, zero   # b = temp (MOV)
    SUBI r4, 1          # count--
    BNE  r4, zero, loop # if count != 0, loop
    SB   r2, 0(zero)    # store result to address 0
    J    halt
halt:
    SYS  1              # HLT
```

---

## Comparison with Real RISC-V

| Feature | RISC-V RV32I | RV8 |
|---------|:---:|:---:|
| `ADD rd, rs1, rs2` | ✅ | ✅ (rd=rs1 implicit) |
| `ADDI rd, rs1, imm` | ✅ | ✅ (rd=rs1 implicit) |
| `LB rd, off(rs)` | ✅ | ✅ |
| `SB rs, off(rs)` | ✅ | ✅ |
| `BEQ rs1, rs2, off` | ✅ | ✅ |
| `JAL rd, off` | ✅ | ✅ |
| `JALR rd, rs, off` | ✅ | ✅ (no offset) |
| `LUI rd, imm` | ✅ | ✅ |
| `SLT rd, rs1, rs2` | ✅ | ✅ |
| No flags register | ✅ | ✅ (hidden internally) |
| r0 = zero | ✅ | ✅ |
| **Syntax match** | — | **~95%** |

---

## Hardware Cost: ZERO change from previous RV8

Same 25 logic chips. Microcode sequences the compare inside branch instructions.
The 74HC74 "flags" chip becomes an internal "branch condition latch" — invisible to programmer.
